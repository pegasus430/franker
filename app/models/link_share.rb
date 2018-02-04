require "net/ftp"

class LinkShare < StoreAPI

  WEBSITE_ID = 3181864

  class << self
    def download_zip_files_via_ftp(store_name, advertiser_id = nil)
      Net::FTP.open("aftp.linksynergy.com", "lfarleigh", "rmR5gjEe") do |ftp|
        ftp.passive = true
        ftp.getbinaryfile("#{advertiser_id}_#{LinkShare::WEBSITE_ID}_mp.xml.gz", "db/data/#{store_name.split(' ').join('').downcase}.gz")
      end
      return File.exists?("db/data/#{store_name.split(' ').join('').downcase}.gz")
    end

    def unzip_gz_files(store_name)
      Zlib::GzipReader.open("db/data/#{store_name.split(' ').join('').downcase}.gz") do |gz|
        contents = gz.read
        File.open("db/data/#{store_name.split(' ').join('').downcase}.xml", "w") do |g|
          g.write(contents)
        end
      end
      return File.exists?("db/data/#{store_name.split(' ').join('').downcase}.xml")
    end

    def get_import_key(product, store_name)
      if store_name == "Steve Madden"
        product["sku_number"]
      elsif store_name.downcase == "asos"
        product.at_css("URL productImage").text.gsub(/[^\d]/, '_').split("_").select {|c| c if c.present? && c.length > 3 }[0]
      elsif store_name.downcase == 'pacsun'
        product.at_css("URL productImage").text.gsub(/[^\d]/, '_').split("_").select {|c| c if c.present? && c.length > 3 }[0]
      else
        product.at_css("URL productImage").text.split('/')[-1].split("?")[0].split(".")[0].split("-")[0]
      end
    end

    def extract_xml(store_name)
      puts "Beginning to extract products for #{store_name}"
      xml_content = Nokogiri::XML(File.open("db/data/#{store_name.split(' ').join('').downcase}.xml"))
      @store = Store.find_by(name: store_name)
      import_keys = []
      xml_content.css('merchandiser product').reverse.each do |product|
        unless product.attributes.size == 0
          if product.at_css("category primary").present?
            import_key = get_import_key(product, store_name)
            import_key = "#{@store.name.split(' ').join('').downcase}_#{import_key}"
            import_keys << import_key
            import_data(import_key, product, @store)
          end
        end
      end
      
      make_items_sold(import_keys.compact.uniq, @store)
      complete_item_creation(@store)
    end

    def importing(store_name, categories_to_exclude=nil)
      xml_content = Nokogiri::XML(open("db/data/#{store_name.split(' ').join('').downcase}.xml"))
      @store = Store.find_by(name: store_name)
      import_keys = []
      xml_content.css('merchandiser product').each do |product|
        unless product.attributes.size == 0
          category_name = get_category_from_url(product.at_css("URL product").text)
          unless (!categories_to_exclude.nil?) && categories_to_exclude.include?(category_name)
            import_key = "#{@store.name.split(' ').join('').downcase}_#{get_import_key(product, store_name)}"
            import_keys.push(import_key)
            begin
              import_data(import_key, product, @store, categories_to_exclude)

              break ## debug
            rescue Exception => e
              puts "^" * 40
              puts "Error importing item from #{store_name} with import_key: #{import_key}"
              puts "Error: #{e}"
              puts "^" * 40
            end
          end
        end
      end
      puts "total products count: #{xml_content.css('merchandiser product').count}"
      puts "Uniq Import Keys count: #{import_keys.size}"
      make_items_sold(import_keys, @store)
    end

    def find_category(product, store, categories_to_exclude=nil)
      if store.name == "Forever 21"
        category_name = get_category_from_url(product.at_css("URL product").text)
      else
        category_name = product.at_css("category primary").text
      end
      unless (!category_name.downcase.include?("womens") && (category_name.downcase.include?("mens") || category_name.downcase.include?("boys")))
        unless (!categories_to_exclude.nil?) && categories_to_exclude.include?(category_name)
          category = store.categories.find_or_initialize_by(name: category_name, overall_category: false, category_type: "External")
        end
        if category.present?
          category.url =""
          category.save
          category
        end
      end
    end

    def get_category_from_url(url)
      decode_url = URI.decode_www_form_component(url)
      parse_data = URI.parse(decode_url)
      hash_data = CGI::parse(decode_url)
      hash_data["Category"].first
    end

    def corrected_name_for(store, name)
      ["FOREVER 21 ", "All Saints ", "Forever 21 ", "AllSaints "].each do |n|
        name = name.split(n).last.strip
      end
      name
    end
    
    def get_color_code_from swatch_url
      swatch_url.split("-").last.sub(".jpg", "")
    end

    def price_value(product)
      retail_price = product.at_css("price retail").text
      sale_price = product.at_css("price sale").present? ? product.at_css("price sale").text : ""
      price = sale_price.present? ? sale_price : retail_price
      msrp = sale_price.present? ? retail_price : 0
      if sale_price == retail_price
        price = retail_price
        msrp = 0
      end
      {price: price, msrp: msrp}
    end

    def import_data(import_key, product, store, categores_to_exclude=nil)
      category = find_category(product, store, categores_to_exclude)
      colors_and_more_info = nil
      if import_key.present? && category.present?
        @item = store.items.find_or_initialize_by(import_key: import_key)
        @is_new_item = !(@item.persisted?)
        price = convert_to_cents(price_value(product)[:price])
        msrp = convert_to_cents(price_value(product)[:msrp])

        if @item.present? && @item.url.present? && (@item.url.include?("%2Fmen") || @item.url.include?("%2Fboy"))
          @item.destroy
          @item = nil
        end
        item_name = corrected_name_for(store, product.attributes["name"].value)
        if @item.present? && (!item_name.downcase.include?("womens")) && (item_name.downcase.include?("mens") || item_name.downcase.include?("boys"))
          @item.destroy
          @item = nil
        end
        
        if @item.present?
          item_url = product.at_css("URL product").text
          if store.name == "Topshop"
            item_url = item_url.gsub("http://click.linksynergy.com/link?id=8Bd/e4Vw38M", "http://click.linksynergy.com/deeplink?id=8Bd/e4Vw38M&mid=#{Topshop::ADVERTISER_ID}")
          elsif store.name == "Forever 21"
            item_url = item_url.gsub("http://click.linksynergy.com/link?id=8Bd/e4Vw38M", "http://click.linksynergy.com/deeplink?id=8Bd/e4Vw38M&mid=#{Forever::ADVERTISER_ID}")
          end
          
          colors_and_more_info = scrape_more_info(item_url, import_key, product) unless item_url.nil?
          colors = colors_and_more_info.present? && colors_and_more_info[:colors_info].present? ? colors_and_more_info[:colors_info] : nil
          secondary_images = colors_and_more_info.present? && colors_and_more_info[:secondary_images].present? ? colors_and_more_info[:secondary_images] : nil
          if @item.persisted? && @item.image.present?
            update_item(@item, store, category, item_url, price, msrp, secondary_images, colors)
          else
            if store.name.downcase == "wildfox"
              image_url = product.at_css("URL productImage").text.gsub(/265x/i, "1080x")
            elsif store.name == "Topshop"
              image_url = product.at_css("URL productImage").text.sub("_normal", "_large")
            else
              image_url = product.at_css("URL productImage").text.sub("_normal", "_2_large")
            end
            availability = product.at_css("shipping availability")
            sold_out = (availability.text.downcase == "in stock") ? false : true if availability.present?
            
            create_new_item(@item, store, category, import_key, image_url, item_url, item_name, price, msrp, DateTime.now, secondary_images, colors, sold_out)
          end
        end
        
        if @item.present? && @item.image.present? && colors_and_more_info.present?
          update_more_info(@item, colors_and_more_info[:size], colors_and_more_info[:description], colors_and_more_info[:more_info])
        elsif @is_new_item && @item.present?
          AlgoliaWorker.add_item_to_algolia(@item)
        end
      end
    end
    
    #############################
    ######### More Info #########
    #############################
    def has_more_info
      false
    end
    
    def scrape_more_info(item_url, item_import_key, product)
      return nil
    end

    def build_images_from swatch_url
      ["1_front_750", "2_side_750", "3_back_750", "4_full_750", "5_detail_750", "6_flat_750", "7_additional_750"].collect { |str| swatch_url.gsub("sw_22", str) }
    end
    
    #######################
    ##### Bulk Upload #####
    #######################
    def bulk_import(store_name)
      xml_content = Nokogiri::XML(open("db/data/#{store_name.split(' ').join('').downcase}.xml"))
      @store = Store.find_by(name: store_name)
      data = []
      conn = ActiveRecord::Base.connection
      import_keys_count = xml_content.css('merchandiser product').flat_map {|product| ("#{@store.name.split(' ').join('').downcase}_#{product.at_css("URL productImage").text.split('/')[-1].split("?")[0].split(".")[0]}") unless product.attributes.size == 0 }.uniq
      import_keys = []
      puts "total products count: #{xml_content.css('merchandiser product').count}"
      puts "Uniq Import Keys count: #{import_keys_count.size}"
      xml_content.css('merchandiser product').each do |product|
        unless product.attributes.size == 0
          import_key = "#{@store.name.split(' ').join('').downcase}_#{get_import_key(product, store_name)}"
          unless import_keys.include?(import_key)
            price = convert_to_cents(price_value(product)[:price])
            msrp = convert_to_cents(price_value(product)[:msrp])
            name = product.attributes["name"].value
            url = product.at_css("URL product").text
            sold_out = (product.at_css("shipping availability").text.downcase == "in stock") ? false : true
            image_url = product.at_css("URL productImage").text.sub("_normal", "_large")
            active = image_url.present? ? true : false
            if image_url.present?
              data.push "('#{price}', '#{msrp}', '#{import_key}', '#{name.gsub("'", "")}', '#{url}', #{active}, #{sold_out}, #{@store.id}, true, '#{image_url}', '#{Time.now.utc.to_s(:db)}', '#{Time.now.utc.to_s(:db)}')"
            end
            import_keys.push(import_key)
          end
        end
        # Save 100 items at a time
        if data.size == 100
          conn.execute("INSERT INTO items (`price`, `msrp`, `import_key`, `name`, `url`, `active`, `sold_out`, `store_id`, `new_one`, `image_url`, `created_at`, `updated_at`) VALUES
            #{data.join(', ')}")
          data = []
        end
      end
      make_items_sold(import_keys, @store)
    end

    def bulk_upload_categories(store)
      conn = ActiveRecord::Base.connection
      data = []
      store.items.find_each do |item|
        category_name = get_category_from_url(item.url)
        unless category_name == "Apparel"
          data.push "('#{category_name}', #{store.id}, 'External', '', false, '', '#{Time.now.utc.to_s(:db)}', '#{Time.now.utc.to_s(:db)}')"
        end
      end
      conn.execute("INSERT INTO categories (`name`, `store_id`, `category_type`, `url`, `overall_category`, `special_tag`, `created_at`, `updated_at`) VALUES #{data.join(', ')}")
    end
    
    def should_delete_item_based_on_name(item_name)
      !item_name.downcase.include?("womens") && (item_name.downcase.include?("mens") || item_name.downcase.include?("boys"))
    end
  end
end