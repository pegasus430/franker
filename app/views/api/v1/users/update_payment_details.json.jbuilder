if @data[:address_details].present?
  json.sales_tax_amount @address_details[:sales_tax_amount]
  json.address_details do
    json.full_name @address_details[:full_name]
    json.zipcode  @address_details[:zipcode]
    json.apt_no @address_details[:apt_no]
    json.street_address @address_details[:street_address]
  end
end
if @data[:card_details].present?
  if @data[:card_details][:status].present?
    json.card_error do
      json.message @data[:card_details][:error]
    end
    json.card_status @data[:card_details][:status]
  end
end
if @data[:default_payment_method].present?
  json.default_payment_method @data[:default_payment_method]
end