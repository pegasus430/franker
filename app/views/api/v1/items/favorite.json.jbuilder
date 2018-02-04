if @item.present?
  json.status "Success"
  json.item_id @item.id
  json.item_name @item.name
else
  json.status "failure"
  json.item_id @item.id
  json.item_name @item.name
  json.error "#{@item.errors.full_messages}"
end