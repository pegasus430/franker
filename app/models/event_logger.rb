require 'mixpanel-ruby'

class EventLogger
  
  class << self
    def api_key
      (Rails.env == "production") ? "70ee6b759b1ac1aa9819c1f22ab1b894" : "41028c54463b2e5a515ebee7802e0918"
    end
  
    def api_secret
      (Rails.env == "production") ? "70ea16533c9cae4a89e80cb0c83a8b71" : "907ed2021e1d8964f2286760d88ce38c"
    end
    
    def token
      (Rails.env == "production") ? "afcc966e71e39ba665547ea73bd94c3a" : "b2013cff84910ba9b6a1d022e83921ba"
    end
  
    def tracker
      @@tracker = Mixpanel::Tracker.new(token)
    end
  
    def log_order_confirmed(order)
      order.order_items.each do |order_item|
        tracker.track( distinct_id_for_user(order.user), 'Retail Order Confirmed', {
        'uuid' => order.user.uuid,
        'email' => order.user.email,
        'retailer' => order_item.store.name,
        'item_amount' => '%.2f' % (order.total_amount.to_f/100.round(2))
        })
      end
    end
    
    def log_order_shipped(order)
      order.order_items.each do |order_item|
        tracker.track( distinct_id_for_user(order.user), 'Order Shipped', {
        'uuid' => order.user.uuid,
        'email' => order.user.email,
        'retailer' => order_item.store.name,
        'item_amount' => '%.2f' % (order.total_amount.to_f/100.round(2))
        })
      end
    end
    
    def log_order_sold_out(order)
      puts "I'm in here"
      order.order_items.each do |order_item|
        puts "api_key"
        tracker.track( distinct_id_for_user(order.user), 'Order Sold Out', {
        'uuid' => order.user.uuid,
        'email' => order.user.email,
        'retailer' => order_item.store.name,
        'item_amount' => '%.2f' % (order.total_amount.to_f/100.round(2))
        })
      end
    end
      
    def distinct_id_for_user(user)
      expire_time = Time.now.to_i + 10
      uuid = user.uuid
      sig = Digest::MD5.hexdigest("api_key=#{api_key}expire=#{expire_time}selector=(properties[\"uuid\"]==\"#{uuid}\")#{api_secret}")
      url = "http://mixpanel.com/api/2.0/engage?selector=(properties[\"uuid\"]==\"#{uuid}\")&api_key=#{api_key}&expire=#{expire_time}&sig=#{sig}"
    
      page_data = Curl.get(url).body
      json_data = JSON.parse(page_data)
      distinct_id = json_data["results"][0]["$distinct_id"]
      if distinct_id.nil?
        distinct_id = "server"
      end
      
      distinct_id
    end
      
  end
end