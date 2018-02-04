json.user @user do |user|
  json.status "Success"
  json.id user.id
  json.imei user.imei
  json.uuid user.uuid
end