class AdminAlertMailer < ActionMailer::Base
  default from: "christie@usedote.com"
  def store_update_email
    subject = "All Stores Updated Successfully! <eom>"
    @message = ""
    yesterday_datetime = (DateTime.now.to_time - 24.hours).to_datetime
    Store.active.each do |store|
      if store[:items_updated_at] < yesterday_datetime
        subject = "URGENT: Stores Not Updated"
        @message << "#{store.name}\n"
      end
    end
    mail(to: ["christie@usedote.com", "lauren@usedote.com"], from: "Sidekiq Monitor <hello@usedote.com>", subject: subject)
  end
  
  def confirmation(retailer_order, send_to_self)
    order = retailer_order.orders[0]
    store = order.order_items[0].store
    address = order.address
    @full_name = address.full_name
    @first_name = @full_name.split(" ")[0]
    @street_address = address.street_address
    if address.city.nil? || address.state.nil?
      @street_address_2 = address.zipcode
    else
      @street_address_2 = "#{address.city}, #{address.state}, #{address.country} #{address.zipcode}"
    end
    @payment_method = order.transaction_payment_method
    @store_image_url = store.logo_icon.url
    subject = "Your #{store.name} Order Is Confirmed!"
    
    @order_number = retailer_order.confirmation_number
    
    @sub_total = 0
    @tax = 0
    @total = 0
    @items = []
    retailer_order.orders.each do |order|
      order_item = order.order_items[0]
      item_total = "$#{'%.2f' % (order.item_amount.to_f/100).round(2)}"
      item_dict = {item_name: order_item.item.name, item_color: order_item.color, item_size: order_item.size, item_amount: item_total, item_image_url: order_item.item.image.file.url}
      if order_item.item.msrp > order_item.item.price
        item_dict[:original_amount] = "$#{'%.2f' % (order_item.item.msrp.to_f/100).round(2)}"
      end
      @items << item_dict
    end
    
    @sub_total = "$#{retailer_order.sub_total_amount}"
    @tax = "$#{retailer_order.sales_tax_amount}"
    @total = "$#{retailer_order.total_amount}"
    
    recipients = [order.user.email]
    if send_to_self
      recipients = ["doteshopping@orders-doteshopping.com"]
    end
    mail(to: recipients, bcc: ["doteshopping@orders-doteshopping.com"], from: "Dote Team <doteshopping@orders-doteshopping.com>", subject: subject)
  end
  
  def shipping(retailer_order, send_to_self)
    order = retailer_order.orders[0]
    store = order.order_items[0].store
    address = order.address
    @full_name = address.full_name
    @first_name = @full_name.split(" ")[0]
    @street_address = address.street_address
    if address.city.nil? || address.state.nil?
      @street_address_2 = address.zipcode
    else
      @street_address_2 = "#{address.city}, #{address.state}, #{address.country} #{address.zipcode}"
    end
    @payment_method = order.transaction_payment_method
    @store_image_url = store.logo_icon.url
    subject = "Your #{store.name} Order Has Shipped!"
    
    @tracking_number = retailer_order.tracking_number
    @tracking_url = retailer_order.tracking_url
    @order_number = retailer_order.confirmation_number
    
    @sub_total = 0
    @tax = 0
    @total = 0
    @items = []
    retailer_order.orders.each do |order|
      order_item = order.order_items[0]
      item_total = "$#{'%.2f' % (order.item_amount.to_f/100).round(2)}"
      item_dict = {item_name: order_item.item.name, item_color: order_item.color, item_size: order_item.size, item_amount: item_total, item_image_url: order_item.item.image.file.url}
      if order_item.item.msrp > order_item.item.price
        item_dict[:original_amount] = "$#{'%.2f' % (order_item.item.msrp.to_f/100).round(2)}"
      end
      @items << item_dict
    end
    
    @sub_total = "$#{retailer_order.sub_total_amount}"
    @tax = "$#{retailer_order.sales_tax_amount}"
    @total = "$#{retailer_order.total_amount}"
    
    recipients = [order.user.email]
    if send_to_self
      recipients = ["doteshopping@orders-doteshopping.com"]
    end
    mail(to: recipients, bcc: ["doteshopping@orders-doteshopping.com"], from: "Dote Team <doteshopping@orders-doteshopping.com>", subject: subject)
  end
end