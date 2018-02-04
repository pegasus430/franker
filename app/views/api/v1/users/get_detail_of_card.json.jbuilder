if @user.present?
  json.name @user.name
  json.email @user.email
  json.imei @user.imei
  json.uuid @user.uuid
  if @user.address.present?
    json.address_details do
      json.full_name @user.address.full_name
      json.zipcode @user.address.zipcode
      json.street_address @user.address.street_address
      json.apt_no @user.address.apt_no
    end
  end
  json.sales_tax_amount @user.get_sales_tax
  if @default_payment_method_hash.present? && @default_payment_method_hash[:status] == "Success"
    json.default_payment_method @default_payment_method_hash
  end
else
  json.status "failure"
  json.error "User not present"
end