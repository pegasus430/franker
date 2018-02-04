class Ebay < StoreAPI
  AFFILIATE_ID = 124248
  FEED_URL = "http://feeds.pepperjamnetwork.com/product-catalog/download"
  KEY = "d30244cbc552071b7a013d9bb135fb65d725569889401f91e55ece700f0937a4"
  EBayEnterpriseAffiliateNetwork.api_key = Ebay::KEY
  
  class << self
    def client
      EBayEnterpriseAffiliateNetwork::Publisher.new
    end

    def get_response(params)
      client.get("creative/product", params)
    end

    def get_category(store, category_program)
      category_name = if (category_names = category_program.split(">")).size > 1
        category_names.last
      else
        category_names.first.humanize
      end
      unless (!category_name.downcase.include?("womens") && (category_name.downcase.include?("mens") || category_name.downcase.include?("boys")))
        category = store.categories.find_or_initialize_by(name: category_name.strip, overall_category: false, category_type: "External")
        category.save! if category.new_record?
        category
      end
    end

    def get_category_id(store, category_program)
      send(:get_category, store, category_program).id
    end

    def create_items(store_name, program_id)
      store = Store.where(name: store_name).first
      current_page = 1
      import_keys = []
      tries = 2
      params = { programIds: program_id, page: current_page }
      response = get_response(params) rescue retry unless (tries -= 1).zero?
      import_keys = import_items(response.data, store)
      total_pages = response.meta.pagination.total_pages
      if total_pages > 1
        current_page = current_page + 1
        loop do
          tries = 2
          params.merge!(page: current_page)
          import_keys << import_items(get_response(params).data, store).flatten.dup rescue retry unless (tries -= 1).zero?
          current_page = current_page + 1
          break if current_page > total_pages
        end
      end
      
      make_items_sold(import_keys, store)
      complete_item_creation(store)
    end

    def import_items(data, store, opts = {})
      items = []
      all_import_keys = []
      conn = ActiveRecord::Base.connection
      data.each do |row|
        import_key = import_key_for(row)
        all_import_keys << import_key
        item = store.items.find_or_initialize_by(import_key: import_key)
        
        price = (row.price.to_f * 100).to_i
        msrp = 0
        item_url = row.buy_url
        sold_out = row.in_stock == "yes" ? false : true
        
        category = nil
        if row.category_program.present?
          category = get_category(store, row.category_program)
        end
        if row.category_network.present?
          category = get_category(store, row.category_network)
        end
          
        if item.present? && item.persisted?
          if category.present?
            update_item(item, store, category, item_url, price, msrp, nil, nil)
            
            unless item.try(:image).try(:file).present?
              image_url = image_url_from(row)
              @image = create_image(image_url_from(row))
              if @image.present?
                item.update(
                  image_url: image_url,
                  image_id: @image.id
                )  
              end
            end
            active = item.image.present? && item.image.persisted?
            item.update(
              active: active,
              sold_out: sold_out
            )
          end
        else
          item_name = row.name
          image_url = row.image_url.gsub("t130x152.jpg", "enh-z5.jpg").
                                    gsub("t382x651.jpg", "enh-z5.jpg").
                                    gsub("outfit_t143x167.jpg", "outfit_t382x651.jpg")
          if category.present?
            create_new_item(item, store, category, import_key, image_url, item_url, item_name, price, msrp, Time.now.utc.to_s(:db), nil, nil, sold_out)
          end
        end
      end

      all_import_keys
    end
  end
end