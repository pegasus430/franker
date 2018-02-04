json.count @stores.count
json.stores @stores do |store|
  json.name store.name
  json.url store.url
  json.position store.position
  json.image_data do
    json.file_name store.image.file_name
    json.content_type store.image.content_type
    json.file_size store.image.file_size
    json.file store.image.file
  end
  json.logo store.logo_icon_file_name
end