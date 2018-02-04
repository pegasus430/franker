class Shopsense
  DEVELOPER_KEY = "uid36-25630006-47"

  class << self
    def products(brand_id, limit, offset)
      url = "http://api.shopstyle.com/api/v2/products?pid=#{Shopsense::DEVELOPER_KEY}&fl=b#{brand_id}&limit=#{limit}&offset=#{offset}"
      JSON.parse(Curl.get(url).body)
    end

    def get_category(name, store)
      category = store.categories.find_or_initialize_by(name: name, overall_category: false, category_type: "External")
      if category.present?
        category.url =""
        category.save
        category
      end
    end

    def import_data(product, store, import_key)
      category = get_category(product["categories"][0]["name"], store)
      name = product["name"]
      if product["salePrice"].present?
        msrp = product["price"]
        price = product["salePrice"]
      else
        msrp = "0"
        price = product["price"]
      end
      puts "Price: #{price}, msrp: #{msrp}"
      sold_out = product["inStock"] ? false : true
      url = product["clickUrl"]

      if import_key.present?
        @item = store.items.find_or_initialize_by(import_key: import_key)
        is_new_item = !(@item.persisted?)
        should_save_item = true
        unless @item.persisted? && @item.image.present?
          @image = create_image(product["image"]["sizes"]["Best"]["url"])
          if @image.present? && @image.persisted?
            @item.image_id = @image.id
            @item.active = @image.present?
            @item.new_one = true
          else
            should_save_item = false
          end
        end

        if !should_save_item || (!name.downcase.include?("womens")) && (name.downcase.include?("mens") || name.downcase.include?("boys"))
          @item.destroy
          @item = nil
        else
          if msrp != '0' && (convert_to_cents(price) != convert_to_cents(msrp)) && (convert_to_cents(price) > convert_to_cents(msrp))
            @item.price = convert_to_cents(msrp)
            @item.msrp = convert_to_cents(price)
          else
            @item.price = convert_to_cents(price)
            @item.msrp = convert_to_cents(msrp)
          end
          @item.category_id = category.id if category.present?
          @item.sold_out = sold_out
          @item.url = url
          if name.length > 255
            name = name[0, 254]
          end
          @item.name = name

          begin
            @item.save!
          rescue Exception => e
            puts "^" * 40
            puts "Exception Occurred for Item"
            puts "item : #{@item.errors}"
            puts "Error: #{e}"
            puts "^" * 40
          end

          unless sold_out
            information_array = product["description"].split("<ul>")
            description = information_array[0]
            more_info = []
            unless information_array.size <= 1 || information_array[1].nil?
              information_array[1].gsub("</li>", "").gsub("</ul>", "").split("<li>").each do |info|
                unless info.gsub(" ", "").length == 0
                  more_info << info
                end
              end
            end
            sizes_array = []
            product["sizes"].each do |size|
              sizes_array << size["name"]
            end
            @item.update(description: description, more_info: more_info, size: sizes_array)
            color_import_keys = []
            product["colors"].each do |color|
              color_name = color["name"]
              color_import_key = "#{import_key}_#{color_name}"
              color_import_keys << color_import_key
              update_item_color(color, @item, sizes_array, color_import_key)
            end
            @item.item_colors.where.not(import_key: color_import_keys).update_all(active: false)
            @item.update(active: @item.item_colors.active.count > 0)
          end
        end

        if (is_new_item)
          AlgoliaWorker.add_item_to_algolia(@item)
        end
        puts "Item Created !!!!!!!!!"
        puts "Item Details : #{@item.inspect}"
        puts ""
      end
    end

    def create_items(store, brand_id, secondary_store=nil, product_name_match=nil)
      @store = store
      url = "http://api.shopstyle.com/api/v2/products?pid=#{Shopsense::DEVELOPER_KEY}&fl=b#{brand_id}"
      products_hash = JSON.parse(Curl.get(url).body)
      total_products_count = products_hash["metadata"]["total"]
      total_pages = (total_products_count / 50).round.to_i
      import_keys = []
      secondary_import_keys = []
      (0..(total_pages - 1)).each do |page|
        puts "Current page: #{page}"
        products = products(brand_id, (page + 1) * 50, page * 50)
        products["products"].each do |product|
          product_name = product["name"]

          product_store = store
          import_key = nil
          if ((!secondary_store.nil?) && (!product_name_match.nil?) && (product_name.include? product_name_match))
            product_store = secondary_store
            import_key = "pink_#{product["id"]}" if product["id"].present?
            secondary_import_keys << import_key if import_key.present?
          else
            import_key = "victoria_secret_#{product["id"]}" if product["id"].present?
            import_keys << import_key if import_key.present?
          end
          import_data(product, product_store, import_key)
        end
      end

      make_items_sold(import_keys, store)
      if secondary_store.present?
        make_items_sold(secondary_import_keys, secondary_store)
        secondary_store.items_updated_at = DateTime.now
        secondary_store.save
      end

      @store.items_updated_at = DateTime.now
      @store.save
    end

    def make_items_sold(import_keys, store)
      puts "Make Items Sold"
      items_that_are_now_sold_out = store.items.where.not(import_key: import_keys).where(sold_out: false)
      puts " Making #{items_that_are_now_sold_out.size} items sold out"
      items_that_are_now_sold_out.update_all(sold_out: true)
      items_that_are_now_sold_out.each do |item|
        if item.present? && item.persisted?
          AlgoliaWorker.delete_item_from_algolia(item)
        end
      end

      store.items.where(import_key: import_keys).update_all(sold_out: false)
    end

    def convert_to_cents(price)
      price = (price.present? && price != 0) ? price.to_f * 100 : 0
      price.to_i
    end

    def create_item_color(color_doc, item, sizes, color_import_key)
      color_name = color_doc["name"]
      puts "Creating item color with name: #{color_name}"
      @color_image = create_image(color_doc["swatchUrl"])
      color_image_id = @color_image.present? ? @color_image.id : nil
      @item_color = item.item_colors.create(url: item.url, sizes: sizes, image_id: color_image_id, item_id: item.id, import_key: color_import_key, color: color_name)
      if color_doc["image"].present?
        create_image(color_doc["image"]["sizes"]["Best"]["url"], @item_color.id, "ItemColor")
      else
        puts "WARNING: could not find image for item color"
      end

      @item_color
    end

    def update_item_color(color_doc, item, sizes, color_import_key)
      color_name = color_doc["name"]
      @item_color = item.item_colors.find_or_initialize_by(import_key: color_import_key)
      if @item_color.persisted?
        @item_color.update(url: item.url, sizes: sizes, item_id: item.id, color: color_name)
      else
        @item_color = create_item_color(color_doc, item, sizes, color_import_key)
      end

      unless @item_color.nil?
        if @item_color.sizes.empty? || @item_color.images.count == 0 || @item_color.color.blank? || @item_color.image_id.blank?
          @item_color.update(active: false)
        else
          @item_color.update(active: true)
        end
      end

      @item_color.save!
      puts "Created item color: #{@item_color.inspect}"
    end

    def create_image(image_url, imageable_id=nil, type=nil)
      puts "Creating image with url: #{image_url} with imageable_id: #{imageable_id} type: #{type}"
      if imageable_id.present? && type.present?
        @image = Image.new(imageable_type: type, imageable_id: imageable_id)
      else
        @image = Image.new
      end
      @image.remote_file_url = image_url
      begin
        @image.save
        Curl.get(@image.file.url)
        puts "Created image: #{@image.file.url}"
      rescue Exception => e
        puts "^" * 40
        puts "Exception Occurred for Image Creation"
        puts "Image URL : #{image_url}"
        puts "Image Details : #{@image.inspect}"
        puts "Error: #{e}"
        puts "^" * 40
      end
      @image
    end
  end
end