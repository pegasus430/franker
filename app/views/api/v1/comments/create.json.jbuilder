json.comment @comment do |comment|
  json.status "Success"
  json.id comment.id
  json.item_id comment.item_id
  json.user_id comment.user_id
end