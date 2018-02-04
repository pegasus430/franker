class RetailerOrder < ActiveRecord::Base
  has_many      :orders
  
  def total_amount
    total_amount = 0
    self.orders.each do |order|
      total_amount = total_amount + order.total_amount.to_f/100
    end
    
    '%.2f' % total_amount.round(2)
  end
  
  def sales_tax_amount
    sales_tax_amount = 0
    self.orders.each do |order|
      sales_tax_amount = sales_tax_amount + order.sales_tax_amount.to_f/100
    end
    
    '%.2f' % sales_tax_amount.round(2)
  end
  
  def sub_total_amount
    sub_total_amount = 0
    self.orders.each do |order|
      sub_total_amount = sub_total_amount + order.item_amount.to_f/100
    end
    
    '%.2f' % sub_total_amount.round(2)
  end
  
  def order_confirmed
    self.orders.each do |order|
      order.order_confirmed
    end
  end
  
  def submit_for_settlement
    orders_settled_successfully = true
    errors = []
    self.orders.each do |order|
      result = order.submit_for_settlement
      orders_settled_successfully = orders_settled_successfully && !result.nil? && result.transaction.present?
      errors << result.errors unless result.nil? || result.success?
    end
    
    return orders_settled_successfully, errors.flatten
  end
  
  def confirmed?
    if self.orders.count == 0
      return false
    end
    
    self.orders.each do |order|
      if !order.confirmed?
        return false
      end
    end
    
    return true
  end
  
  def shipped?
    if self.orders.count == 0
      return false
    end
    
    self.orders.each do |order|
      if !order.shipped?
        return false
      end
    end
    
    return true
  end
  
  def order_placed?
    if self.orders.count == 0
      return false
    end
    
    self.orders.each do |order|
      if !order.order_placed?
        return false
      end
    end
    
    return true
  end
end