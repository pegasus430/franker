if DoteSettings.first.image.present?
  json.dote_picks_image_url DoteSettings.first.image.file.url
end
json.stores @stores do |store|
  items_count = 0
  if @store_new_item_counts.present?
	@store_new_item_counts.each do |item_count_object|
	  if item_count_object.store_id == store.id
	    items_count = item_count_object.count
	    break
	  end
    end
  end
  if items_count > 0
    json.new_items_count items_count > 50 ? "50+" : items_count
  end
  json.id store.id
  json.name store.name
  json.url store.url
  json.more_info store.more_info
  json.payment_status store.payment
  json.more_info store.more_info
  json.isActive store.active
  json.isFavorite @favorite_store_ids.include? store.id
  json.logo store.logo_icon.url
  json.image_url store.image.file.url if store.image.present?
  json.square_logo store.square_logo_icon.url
  json.circle_logo store.circle_logo_icon.url
  json.is_new store.is_new_store(current_user)
end