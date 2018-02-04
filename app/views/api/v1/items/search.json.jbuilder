#json.search_page_count @number_of_pages_for_search
json.items @items do |item|
  json.id item.id
  json.name item.name
  json.url item.url
  json.msrp item.msrp
  json.price item.price
  json.store_name item.store.try(:name)
  json.store_id item.store_id
  if item.image.present?
    json.image_url item.image.file.url
  end
  if item.image.present?
    json.image_url item.image.file.url
  end
  json.color_count item.item_colors.count
  json.sold_out item.sold_out
  if item.category.present?
    json.category item.category.name
  end
  json.sale item.sale?
  if item.store.present?
    json.payment_status item.store.payment
    json.store_more_info item.store.more_info
    if item.store.payment == true
      shipping_details = item.shipping_details(current_user, item.store)
      json.shipping_price shipping_details[:shipping_price]
      json.shipping_badge shipping_details[:shipping_badge]
      json.free_shipping_at shipping_details[:free_shipping_at]
      json.ground_shipping_value item.ground_shipping_value
    end
  end
  #json.favorite item.favorite(current_user)
  json.badge_type item.badge_type(current_user)
  json.batch_time DoteSettings.last.batch_time
end