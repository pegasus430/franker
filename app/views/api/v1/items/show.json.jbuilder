json.id @item.id
json.name @item.name
json.url @item.url
json.msrp @item.msrp
json.price @item.price
json.store_id @item.store_id
json.image_url @item.image.file.url
json.sold_out @item.sold_out
json.seen @item.seen(current_user)
json.favorite @item.favorite(current_user)
json.badge_type @item.badge_type(current_user)
json.image_url @item.image.file.url
json.secondary_images @item.images.map {|i| i.file.url if i.present? && i.file.present? }
if @item.item_colors.present?
  json.colors @item.item_colors do |color_info|
    json.image_url color_info.image.file.url
    json.name color_info.color
    json.rgb color_info.rgb
    json.url color_info.url
    json.sizes color_info.sizes
    json.item_images color_info.images.map {|i| i.file.url }
  end
else
  json.colors []
end
json.sizes @item.convert_sizes(@item.size)
json.description @item.description
json.more_info @item.more_info
if @item.category.present?
  json.category @item.category.name
end
json.sale @item.sale?
if @item.store.present?
  json.payment_status @item.store.payment
  json.store_more_info @item.store.more_info
end
json.batch_time DoteSettings.last.batch_time