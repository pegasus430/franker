if @all_categories.present?
  json.all_category_names @all_categories
end
if @next_page_no.present?
  json.next_page_no @next_page_no
end
json.items_count @items.size
if @all_categories.present?
  json.all_categories_count @all_categories.size
  json.all_category_names @all_categories
end

batch_time = DoteSettings.last.batch_time
json.items @items do |item|
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
  json.seen (@unseen.size == 0)
  # item is obviously not a favorite item if it is unseen
  json.favorite (@unseen.size == 0) && item.favorite(current_user)
  json.badge_type item.badge_type(current_user)
  json.batch_time batch_time
end