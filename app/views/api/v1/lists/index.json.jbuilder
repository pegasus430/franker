json.lists @lists do |list|
  if list.item_lists.present? && list.item_lists.count > 0
    json.id list.id
    json.name list.name
    json.designer_name list.designer_name
    json.designer_url list.designer_url
    json.cover_image list.cover_image.url
    json.content_square_image list.content_square_image.url
  end
end