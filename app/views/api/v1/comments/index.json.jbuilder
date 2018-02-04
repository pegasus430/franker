json.count @comments_count
json.comments @comments do |comment|
  json.id comment.id
  json.message comment.message
  json.user_id comment.user_id
  json.user_name comment.user.name
  json.item_id comment.item_id
  json.created_at comment.created_at
end