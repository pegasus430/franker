class User < ActiveRecord::Base
  serialize :payment_method_data, Hash
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable
  include Tokenable

  has_many      :stores, through: :user_favorite_stores
  has_many      :user_favorite_stores, dependent: :destroy
  has_many      :items, through: :user_items
  has_many      :lists, through: :user_lists
  has_many      :user_lists, dependent: :destroy
  has_many      :user_items, dependent: :destroy
  has_many      :notifications, dependent: :destroy
  has_many      :orders, dependent: :destroy
  belongs_to    :address

  scope :non_admin, -> {where("email != ? || email IS ?", "test@crypsis.net", nil)}

  validates_presence_of :imei

  def error_order_logger
    @@error_order_logger ||= Logger.new("#{Rails.root}/log/error_order.log")
  end

  def success_order_logger
    @@success_order_logger ||= Logger.new("#{Rails.root}/log/success_order.log")
  end

  def customer_id
    "user-#{self.id}"
  end  
  
  def add_address_details(data)
    @address = if self.address_id.present?
      update_address(data[:shipping_address])
    else
      create_address(data[:shipping_address])
    end
    if @address.present?
      sales_tax = find_sales_tax(@address.zipcode)
      customer = find_or_create_customer(data["email"], data["shipping_address"].present? ? data["shipping_address"]["full_name"] : nil)
      if customer.present?
        if data["shipping_address"]["full_name"].present? && (customer.first_name.nil? || customer.first_name != data["shipping_address"]["full_name"]) 
          result = Braintree::Customer.update(
            "#{self.customer_id}",
            :first_name => data["shipping_address"]["full_name"],
            :email => data["email"]
          )
        end
        self.address_id = @address.id
        self.email ||= (data["email"] || data[:email])
        self.save!
      end
      return {sales_tax_amount: sales_tax, full_name: @address.full_name, zipcode: @address.zipcode, apt_no: @address.apt_no, street_address: @address.street_address}
    end
  end
  
  def find_or_create_customer(email=nil, full_name=nil)
    customer_response = find_customer
    customer = if customer_response.present? && customer_response[:status] == "Success"
        customer_response[:customer]
      else
        response = create_braintree_customer(self, email, full_name)
        find_customer[:customer] if response[:customer_id].present?
      end
      
    customer
  end

  def find_customer
    begin
      customer = Braintree::Customer.find("#{self.customer_id}")
    rescue Exception => e
      error_order_logger.info "Error Message while finding customer: #{e}"
      return {customer_present: false, status: "Failure"}
    end
    return {customer_present: true, status: "Success", customer: customer}
  end

  def create_address(address)
    Address.create!(street_address: address[:street_address],
                    apt_no: address[:apt_no],
                    full_name: address[:full_name],
                    zipcode: address[:zipcode])
  end

  def update_address(address)
    @address = Address.find(self.address_id)
    @address.update(street_address: address[:street_address],
                    apt_no: address[:apt_no],
                    full_name: address[:full_name],
                    zipcode: address[:zipcode])
    @address
  end

  def create_braintree_customer(user, email, full_name)
    email = email.nil? ? "" : email
    full_name = full_name.nil? ? "" : full_name
    result = Braintree::Customer.create(
      :id => "#{user.customer_id}",
      :first_name => full_name,
      :email => email
    )
    if result.success?
      puts "Created customer #{result.customer.id}"
      success_order_logger.info("---------- Customer Created ----------")
      success_order_logger.info("Created customer #{result.customer.id}")
      success_order_logger.info("result:  #{result.inspect}")
      success_order_logger.info ""
      return {customer_id: "#{user.customer_id}", status: "Success"}
    else
      puts "Validations failed"
      error_order_logger.info "---------- Customer Failed ----------"
      error_order_logger.info "Validations failed for Customer"
      error_order_logger.info "Email: #{email}"
      error_order_logger.info "For User: #{user.inspect}"
      error_messages = result.errors.map do |error|
        error_order_logger.info "Error Message: #{error.message}"
        error.message
      end
      puts "Error For customer: #{error_messages}"
      error_order_logger.info "---------- Customer Failed ----------"
      error_order_logger.info ""
      return {customer_id: "#{user.customer_id}", error: error_messages, status: "Failure"}
    end
  end


  def get_payment_hash(payment_response)
    if payment_response[:data].instance_of? Braintree::PayPalAccount
      {token: payment_response[:data].token,
       email: payment_response[:data].email,
       card_type_image_url: payment_response[:data].image_url}
    else
      {token: payment_response[:data].token,
       bin: payment_response[:data].bin,
       card_type: payment_response[:data].card_type,
       cardholder_name: payment_response[:data].cardholder_name,
       customer_id: payment_response[:data].customer_id,
       expiration_month: payment_response[:data].expiration_month,
       expiration_year: payment_response[:data].expiration_year,
       last_4: payment_response[:data].last_4,
       card_type_image_url: payment_response[:data].image_url}
     end
  end
  
  def get_default_payment_method_hash
    customer = self.find_or_create_customer
    default_payment_method = nil
    payment_methods_to_delete = []
    if customer.present?
      customer.payment_methods.each do |payment_method|
        if default_payment_method.nil? || default_payment_method.created_at < payment_method.created_at
          payment_methods_to_delete << default_payment_method unless default_payment_method.nil?
          default_payment_method = payment_method
        else
          payment_methods_to_delete << payment_method
        end
      end
    end
    
    payment_methods_to_delete.each do |payment_method|
      Braintree::PaymentMethod.delete(payment_method.token)
    end
    
    if (!default_payment_method.nil?)
      {status: "Success"}.merge(hash_for_payment_method(default_payment_method))
    else
      {status: "Failure"}
    end
  end

  def add_card_details(data)
    if data["card_details"]["nonce"].present?
      customer = find_or_create_customer(data["email"], data["shipping_address"].present? ? data["shipping_address"]["full_name"] : nil)
      
      pm_response = create_braintree_payment_method(data["card_details"], "#{self.customer_id}", self)
      if pm_response[:status] == "Failure" || pm_response[:status] == "Warning"
        return pm_response
      else
        self.update(payment_method_data: get_payment_hash(pm_response))
        return self.payment_method_data
      end
    end
  end

  def create_braintree_payment_method(data, customer_id, user)
    result = Braintree::PaymentMethod.create(
      :customer_id => customer_id,
      :payment_method_nonce => data["nonce"],
      :device_data => data["device_data"],
      :options => {
        :make_default => true
      }
    )
    puts "*" * 40
    puts result.inspect
    puts "*" * 40
    if result.success?
      puts "Created payment method #{result.payment_method.token}"
      puts "Created PM , result:  #{result.inspect}, customer_id: #{customer_id}"
      success_order_logger.info("---------- PM Created ----------")
      success_order_logger.info("Created PM , result:  #{result.inspect}, customer_id: #{customer_id}")
      success_order_logger.info ""
      return {customer_id: customer_id, token: result.payment_method.token, status: "Success", data: result.payment_method}
    else
      if result.errors.size == 1
        result.errors.each do |error|
          if error.code.to_i == 91719 #blah
            return {error: ["You’ve already saved that card!"], status: "Warning", customer_id: customer_id}
          end
        end
      end
      puts "Validations failed in PaymentMethod"
      error_order_logger.info "---------- Payment Method Failed ----------"
      error_order_logger.info "Validations failed for PM"
      error_order_logger.info "Data: #{data}"
      error_order_logger.info "For User: #{user.inspect}"
      error_order_logger.info "Errors: #{result.errors}"
      error_order_logger.info "Result Object: #{result.inspect}"
      error_order_logger.info ""
      error_order_logger.info "Result CVV Verification Object: #{result.credit_card_verification.inspect}"
      error_order_logger.info ""
      if result.credit_card_verification.present?
        error_messages = ["Credit card verification #{result.credit_card_verification.processor_response_text}, Response Code: #{result.credit_card_verification.processor_response_code}, status: #{result.credit_card_verification.status}"]
        error_order_logger.info "Error Message: #{error_messages}"
      else
        error_messages = result.errors.map do |error|
          error_order_logger.info "Error Message: #{error.message}"
          error.message
        end
      end
      error_order_logger.info ""
      puts "Error For payment method: #{error_messages}"
      error_order_logger.info "Error For payment method: #{error_messages}"
      error_order_logger.info "---------- Payment Method Failed ----------"
      error_order_logger.info ""
      return {error: error_messages, status: "Failure", customer_id: customer_id}
    end
  end

  def favorite!(item, value)
    @user_item = find_or_create_user_item(item)
    @user_item.update(favorite: value)
  end

  def favorite_store_ids
    ids = Store.active.pluck(:id)
    user_favorite_stores.where("favorite = true AND store_id IN (#{ids.join(",")})").pluck(:store_id)
  end

  def seen!(item)
    @user_item = find_or_create_user_item(item)
  end

  def find_or_create_user_item(item, try_again=true)
    begin
      UserItem.find_or_create_by(user_id: self.id, item_id: item.id)
    rescue Exception => e
      if try_again
        find_or_create_user_item(item, false)
      end
    end
  end

  def get_sales_tax
    if address.present? && address.zipcode.present?
      @st = SalesTax.find_by(zipcode: address.zipcode)
      @st.present? ? @st.percentage : 0
    else
      0
    end
  end

  def find_sales_tax(zipcode)
    @st = SalesTax.find_by(zipcode: zipcode)
    @st.present? ? @st.percentage : 0
  end

  def admin?
    email == "test@crypsis.net"
  end

  def favorite_items(categories)
    if categories.present?
      @category_items  = categories.map {|c| c.active_items }.flatten.uniq
      user_items.includes(:user, :item).order(created_at: :desc).where(item_id: @category_items.map(&:id), favorite: true).map(&:item)
    else
      user_items.includes(:user, :item).order(created_at: :desc).map{|ui| ui.item if ui.favorite == true }.compact
    end
  end

  def seen_items
    user_items.includes(:user, :item).order(created_at: :desc).map{|ui| ui.item}.compact
  end

  def all_items_seen
    user_items.includes(:user, :item).order(created_at: :desc).map{|ui| ui.item}.compact
  end

  def favorite_store_items(page_no, items)
    @stores = stores.active.includes(:items)
    active_items = @stores.map(&:items).flatten.select {|i| i if i.active == true }.flatten.compact.shuffle
    @items = ((active_items.count.to_f / 10).ceil >= page_no) ? Kaminari.paginate_array(active_items).page(page_no).per(10) : []
    {items: @items, total_count: active_items.flatten.count}
  end
  
  private
  def hash_for_payment_method(payment_method)
    last_4 = ""
    email = ""
    if payment_method.instance_of? Braintree::PayPalAccount
      email = payment_method.email
    elsif payment_method.instance_of? Braintree::CreditCard
      last_4 = payment_method.last_4
    end
    {status: "Success", token: payment_method.token, image_url: payment_method.image_url, last_4: last_4, email: email}
  end
end