json.count @users.count
json.users @users do |user|
  if user.email.present?
    json.email user.email
  end
  json.uuid user.uuid
  json.imei user.imei
  if user.dev_token.present?
    json.dev_token user.dev_token
  end
  if user.last_activity_at.present?
    json.last_activity_at user.last_activity_at
  end
  json.created_at user.created_at
  json.updated_at user.updated_at
end