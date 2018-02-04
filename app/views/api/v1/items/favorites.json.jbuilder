if @next_page_no.present?
  json.next_page_no @next_page_no
end
if @all_categories.present?
  json.all_category_names @all_categories.map(&:name)
end
json.store_filters @store_filters do |store|
  if store.class == Store
    json.id store.id
  elsif @store.present?
    json.id 0
  end
end

batch_time = DoteSettings.last.batch_time
json.items @items do |item|
  json.id item.id
  json.name item.name
  json.url item.url
  json.msrp item.msrp
  json.price item.price
  json.store_id item.store_id
  if item.image.present?
    json.image_url item.image.file.url
  end
  json.color_count item.item_colors.active.count
  json.sizes item.size
  json.sold_out item.sold_out
  if item.category.present?
    json.category item.category.name
  end
  json.sale item.sale?
  if item.store.present?
    if item.store.payment == true
      shipping_details = item.shipping_details(current_user, item.store)
      json.shipping_price shipping_details[:shipping_price]
      json.shipping_badge shipping_details[:shipping_badge]
      json.free_shipping_at shipping_details[:free_shipping_at]
      json.ground_shipping_value item.ground_shipping_value
    end
  end
  json.badge_type item.fav_badge_type(current_user)
  json.seen true
  json.batch_time batch_time
end