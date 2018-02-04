if @user.present?
  json.status "Success"
  json.name @user.name
  json.email @user.email
  json.imei @user.imei
  json.id @user.id
  json.uuid @user.uuid
else
  json.status "failure"
  json.error "User not present"
end