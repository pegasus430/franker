class Address < ActiveRecord::Base

  USPS_USER_ID = "619DOTE07350"

  def error_order_logger
    @@error_order_logger ||= Logger.new("#{Rails.root}/log/error_order.log")
  end
  
  def auto_populate_city_and_state
    begin
      url = "http://production.shippingapis.com/ShippingAPI.dll?API=CityStateLookup&XML=<CityStateLookupRequest USERID=\"#{USPS_USER_ID}\"><ZipCode ID=\"0\"><Zip5>#{self.zipcode}</Zip5></ZipCode></CityStateLookupRequest>"
      result = Nokogiri::XML(open(URI.encode(url), 'User-Agent' => 'DoteBot'))
      city = result.xpath("//ZipCode//City")
      state = result.xpath("//ZipCode//State")
      city = city.text unless city.nil?
      state = state.text unless state.nil?
      self.update(city: city, state: state)
    rescue Exception => e
      error_order_logger.info "Failed to save address: {self.inspect}"
      error_order_logger.info "Error: #{e}"
    end
  end

end