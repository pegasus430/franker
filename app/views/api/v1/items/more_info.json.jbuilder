unless @current_item.nil?
  if @current_item.item_colors.active.valid.present?
    colors = []
    @current_item.item_colors.active.includes(:images, :image).each do |color_info|
      hash = Hash.new
      hash["item_color_id"] = color_info.id
      hash["sizes"] = color_info.sizes.reject { |c| c if c.gsub(" ", "").empty? }
      if color_info.image.present?
        hash["image_url"] = color_info.image.file.url
      end
      hash["rgb"] = color_info.rgb unless color_info.rgb.nil?
      hash["name"] = color_info.color if color_info.rgb.nil? && !color_info.color.nil?
      if color_info.images.present?
        hash["item_images"] = color_info.images.map {|i| i.file.url }
      end
      colors << hash
    end
    json.colors colors
  else
    json.colors []
  end
  json.secondary_images @current_item.images.map {|i| i.file.url if i.present? && i.file.present? }
  json.sizes @current_item.convert_sizes(@current_item.size.reject { |c| c if c.gsub(" ", "").empty? })
  json.description @current_item.description
  json.more_info @current_item.more_info
end

if @similar_items.next_page.present?
  json.next_page_number @similar_items.next_page
end

if @similar_items.present? && !@similar_items.empty?
  batch_time = DoteSettings.last.batch_time
  json.similar_items @similar_items do |item|
  	json.id item.id
  	json.name item.name.lstrip.gsub(/\t/, '') unless item.nil?
  	json.url item.url
  	json.msrp item.msrp
  	json.price item.price
  	json.store_id item.store_id
  	json.sizes item.size
  	if item.image.present?
      json.image_url item.image.file.url
  	end
  	if item.store.present? && item.store.more_info
  	  json.color_count item.item_colors.active.count
  	else
  	  json.color_count 0
  	end
  	json.sold_out item.sold_out
  	if item.category.present?
      json.category item.category.name
  	end
  	json.sale item.sale?
  	if item.store.present? && item.store.payment
      shipping_details = item.shipping_details(current_user, item.store)
      json.shipping_price shipping_details[:shipping_price]
      json.shipping_badge shipping_details[:shipping_badge]
      json.free_shipping_at shipping_details[:free_shipping_at]
      json.ground_shipping_value item.ground_shipping_value
  	end
  	json.badge_type item.badge_type(current_user)
  	json.batch_time batch_time
  end
end