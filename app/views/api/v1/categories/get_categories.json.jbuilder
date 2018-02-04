json.count @categories.count

json.internal_categories @categories do |category|
  json.name category.name
  json.url category.url
  json.parent_id category.parent_id
  json.special_tag category.special_tag
  json.store_id category.store_id
  json.items_count category.items.count
  json.store_name category.store.name
  json.category_type category.category_type
  json.overall_category category.overall_category
  json.created_at category.created_at
  json.updated_at category.updated_at

  json.external_categories category.sub_categories do |subcategory|
    if subcategory.present?
      json.name subcategory.name
      json.url subcategory.url
      json.parent_id category.id
      json.special_tag subcategory.special_tag
      json.items_count subcategory.items.count
      json.category_type subcategory.category_type
      json.store_id subcategory.store_id
      json.store_name subcategory.store.name
      json.overall_category subcategory.overall_category
      json.created_at subcategory.created_at
      json.updated_at subcategory.updated_at
      if subcategory.items.present?
        json.items subcategory.items do |item|
          if item.present?
            json.name item.name
            json.url item.url
            json.price item.price
            json.msrp item.msrp
            json.import_key item.import_key
            json.store_id item.store_id
            json.store_name item.store.name
            json.active item.active
            json.sold_out item.sold_out
            json.trending item.trending
            json.category_id subcategory.id
            json.image_url item.image_url
            json.new_one item.new_one
            json.created_at item.created_at
            json.updated_at item.updated_at
            json.image_data do
              json.file_name item.image.file_name
              json.content_type item.image.content_type
              json.file_size item.image.file_size
              json.file item.image.file
            end
          end
        end
      end
    end
  end
end