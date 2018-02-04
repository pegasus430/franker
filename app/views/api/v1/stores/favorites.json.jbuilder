json.count @stores.count
json.stores @stores do |store|
  json.id store.id
  json.name store.name
  json.payment_status store.payment
  json.isActive store.active
  json.isFavorite store.isFavorite!(current_user)
end