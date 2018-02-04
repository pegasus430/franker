json.list_id @list.id
json.name @list.name
json.cover_image @list.cover_image.url
json.content_square_image @list.content_square_image.url
json.designer_name @list.designer_name if @list.designer_name.present?
json.designer_url @list.designer_url if @list.designer_url.present?

batch_time = DoteSettings.last.batch_time
if @item_lists.present?
  json.items_count @item_lists.flat_map(&:item).compact.uniq.count
  json.items @item_lists do |item_list|
    if item_list.item.present?
      item = item_list.item
      json.position item_list.position
      json.quote item_list.quote
      json.id item.id
      json.name item.name
      json.url item.url
      json.msrp item.msrp
      json.price item.price
      json.store_id item.store_id
  	  json.sizes item.size
      json.sale item.sale?
      if item.store.present?
        json.payment_status item.store.payment
        json.store_more_info item.store.more_info
        if item.store.payment
          shipping_details = item.shipping_details(current_user, item.store)
          json.shipping_price shipping_details[:shipping_price]
          json.shipping_badge shipping_details[:shipping_badge]
          json.free_shipping_at shipping_details[:free_shipping_at]
          json.ground_shipping_value item.ground_shipping_value
        end
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
      json.description item.description
      json.more_info item.more_info
      json.image_url item.image.file.url
      json.favorite item.favorite(current_user)
      json.batch_time batch_time
    end
  end
end