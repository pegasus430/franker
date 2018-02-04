if @item.present?
  json.status "Success"
else
  json.status "failure"
  json.error "#{@item.errors.full_messages}"
end