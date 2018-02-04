if @user.present? && @user.admin?
  json.status "Success"
  json.force_upgrade @user.force_upgrade
  json.rate_this_app_enabled (Setting.find_by key:'rate_this_app_enabled').value
  if @user.force_upgrade
    json.appstore_url @user.appstore_url
  end
else
  json.status "failure"
  json.error "User not present"
end