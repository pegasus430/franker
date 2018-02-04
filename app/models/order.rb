class Order < ActiveRecord::Base
  serialize :errors_hash, Hash

  has_many      :order_items, dependent: :destroy
  belongs_to    :address
  belongs_to    :user
  belongs_to    :retailer_order

  enum status: [ :new_one, :shipped, :processing, :failure, :order_placed, :voided, :confirmed ]

  def error_order_logger
    @@error_order_logger ||= Logger.new("#{Rails.root}/log/error_order.log")
  end

  def success_order_logger
    @@success_order_logger ||= Logger.new("#{Rails.root}/log/success_order.log")
  end

  def create_payment(data, user)
    address_hash = user.address.attributes.except("id", "updated_at", "created_at")
    @address = create_address(address_hash.with_indifferent_access)
    @address.auto_populate_city_and_state
    @order_item = self.order_items.new(item_id: data[:item_information][:item_id],
                                       store_id: data[:item_information][:store_id],
                                       quantity: data[:item_information][:quantity],
                                       item_data: data[:item_information].except(:quantity),
                                       size: data[:item_information][:item_size],
                                       color: data[:item_information][:item_color])

    if user.email.present?
      response = generate_transaction(data, user)
    else
      response = {email_error: "Your email hasn’t been saved yet.  Please tap 'return' after inputting your email to save it."}
    end
    if response.present?
      if response[:transaction_id].present?
        self.update(address_id: @address.id,
                    transaction_id: response[:transaction_id],
                    total_amount: (data[:total_amount].to_f * 100).to_i,
                    shipping_price: (data[:shipping_price].to_f * 100).to_i,
                    sales_tax_amount: (data[:sales_tax_amount].to_f * 100).to_i,
                    item_amount: data[:item_amount].to_f * 100,
                    status: 4,
                    customer_id: response[:customer_id])
        success_order_logger.info "Email: #{data[:email]}, email string: #{data['email']}"
        user.email ||= (data["email"] || data[:email])
        user.save!
      else
        error_order_logger.info "Email: #{data[:email]}, email string: #{data['email']}"
        user.email ||= (data["email"] || data[:email])
        user.save!
        response_error_data = user.email.present? ? response[:error_data] : {email_error: "The User's email hasn't been saved on DataBase."}
        self.update(address_id: @address.id,
                    status: 3,
                    customer_id: response[:customer_id],
                    total_amount: (data[:total_amount].to_f * 100).to_i,
                    shipping_price: (data[:shipping_price].to_f * 100).to_i,
                    sales_tax_amount: (data[:sales_tax_amount].to_f * 100).to_i,
                    item_amount: data[:item_amount].to_f * 100,
                    errors_hash: response_error_data)
      end
    end
    {order: self, response: response}
  end

  def create_address(address)
    Address.create!(street_address: address["street_address"],
                    apt_no: address["apt_no"],
                    full_name: address["full_name"],
                    zipcode: address["zipcode"])
  end
  
  def generate_transaction(data, user)
    customer = user.find_customer[:customer]
    if customer.present?
      response = apply_braintree_transaction(data, customer.id)
    else
      response = {}
    end
    response
  end

  def apply_braintree_transaction(data, customer_id)
    result = nil
    if data[:nonce].present?
      result = Braintree::Transaction.sale(
        :amount => data[:total_amount],
        :payment_method_nonce => data[:nonce],
        :device_data => data[:device_data],
        :customer_id => customer_id
      )
    else
      result = Braintree::Transaction.sale(
        :amount => data[:total_amount],
        :payment_method_token => data[:token],
        :device_data => data[:device_data],
        :customer_id => customer_id
      )
    end
    if result.success?
      puts "success!: #{result.transaction.id}"
      success_order_logger.info("---------- Transaction Created ----------")
      success_order_logger.info("Created Transaction , result:  #{result.inspect}, customer_id: #{customer_id}")
      success_order_logger.info ""
      return {transaction_id: result.transaction.id, status: "Order Placed", customer_id: customer_id}
    elsif result.transaction
      puts "Validations failed in PaymentMethod"
      error_order_logger.info "---------- Transaction Failed ----------"
      error_order_logger.info "Validations failed for transaction: #{result.transaction}"
      error_order_logger.info "Data: #{data}"

      error_order_logger.info "Error processing transaction:"
      error_order_logger.info "  code: #{result.transaction.processor_response_code}"
      error_order_logger.info "  text: #{result.transaction.processor_response_text}"
      error_order_logger.info "Customer ID: #{customer_id}"
      error_order_logger.info "---------- Transaction Failed Ends ----------"
      error_order_logger.info ""
      error_data = {code: result.transaction.processor_response_code,
                    text: result.transaction.processor_response_text,
                    transaction: result.transaction,
                    customer_id: customer_id,
                    data: data}

      return {customer_id: customer_id, status: "Error processing transaction", error_data: error_data}
    else
      error_order_logger.info "---------- Transaction Failed ----------"
      error_order_logger.info "Data: #{data}"
      error_order_logger.info "Customer ID: #{customer_id}"
      error_order_logger.info "Errors: #{result.errors.inspect}"
      error_messages = result.errors.map do |error|
        error_order_logger.info "Error Message: #{error.message}"
        error.message
      end
      error_data = {error_messages: error_messages,
                    result: result.inspect,
                    customer_id: customer_id,
                    data: data}
      error_order_logger.info "---------- Transaction Failed Ends ----------"
      error_order_logger.info ""
      return {customer_id: customer_id, error: error_messages, status: "Failure", error_data: error_data}
    end
  end
  
  def transaction_payment_method
    if self.transaction_id.present?
      transaction = Braintree::Transaction.find(self.transaction_id)
      if transaction.present?
        if transaction.credit_card_details.card_type.present? && transaction.credit_card_details.last_4.present?
          return "#{transaction.credit_card_details.card_type} ending with #{transaction.credit_card_details.last_4}"
        elsif transaction.paypal_details.payer_email.present?
          return "PayPal with email #{transaction.paypal_details.payer_email}"
        elsif transaction.payment_instrument_type == "apple_pay_card"
          return "ApplePay"
        end
      end
    end
  end
  
  def submit_for_settlement
    if self.confirmed?
      result = Braintree::Transaction.submit_for_settlement(self.transaction_id, (self.total_amount.to_f/100).to_f)
      if result.transaction.present?
        self.order_shipped
      end
    end
    result
  end
  
  def find_retailer_order
    retailer_order_id = nil
    store_id = self.order_items[0].store_id
    orders = Order.where(user_id: self.user_id, status: 4).where.not(retailer_order_id: 0)
    orders.each do |order|
      order.order_items.each do |order_item|
        if order_item.store_id == store_id
          retailer_order_id = order.retailer_order_id
          break
        end
      end
      unless retailer_order_id.nil?
        break
      end
    end
    
    if retailer_order_id.nil?
      retailer_order = RetailerOrder.new
      retailer_order.save!
      retailer_order_id = retailer_order.id
    end
    self.update(retailer_order_id: retailer_order_id)
  end
  
  def order_confirmed
    EventLogger.log_order_confirmed(self)
    self.order_items.each do |order_item|
      order_item.update(confirmed_at: DateTime.now)
    end
    self.update(status: 6)
  end
  
  def order_shipped
    EventLogger.log_order_shipped(self)
    self.order_items.each do |order_item|
      order_item.update(shipped_at: DateTime.now)
    end
    self.update(status: 1)
  end
end