class Gap < StoreAPI
  DOMAIN = "www.gap.com"
  API_URL = "http://#{self::DOMAIN}/resources/productSearch/v1/search?cid=%%cid%%&style=%%style%%"
  PRODUCT_URL = "http://#{self::DOMAIN}/browse/product.do?cid=%%child_cid%%&pid=%%PID%%"
  PRODUCT_RESOURCE_URL = "http://#{self::DOMAIN}/browse/productData.do?pid=%%pid%%&vid=1&scid=&actFltr=false&locale=en_US&internationalShippingCurrencyCode=&internationalShippingCountryCode=us&globalShippingCountryCode=us"
  REG_EX = /.+\?cid=(\d*).*?|&style=(\d*)/i
  GENERIC_IMAGE_REGEX = 'objP\.StyleColor\(\"%%pid%%\".*styleColorImagesMap\s=\s{.*\'Z\':\s\'(.*?.jpg).*}\;objP\.setArrayVariantStyleColorImages\(objP\.arrayVariantStyles\["1"\]\.arrayVariantStyleColors\[%%position%%\]'
  PRODUCT_OCCURANCE_REGEX = /objP\.StyleColor\(\"(\d*)\"/i
  IMPORT_KEY_PREFIX = "gap_"
  STORE_NAME = "Gap"
  class << self
    
    def store_items
      @store = Store.find_by(name: self::STORE_NAME)
      @categories = @store.categories.external
      @items = []
      created_at = DateTime.now
      imported_pids = []            
      @categories.reverse.each do |category|        
        next if category_api_url(category).blank?        
        response = JSON.parse(Curl.get(category_api_url(category)).body).with_indifferent_access rescue nil

        next if response.blank?
        puts "#{self::STORE_NAME} category : #{category.url}"
        
        child_categories = response[:productCategoryFacetedSearch][:productCategory][:childCategories] rescue nil
        if child_categories
          if child_categories.is_a?(Array)
            child_categories.each do |child_category|
              @items = []
              fetch_obj = fetch_page_data(child_category, imported_pids)               
              @items << [fetch_obj[:items]]
              imported_pids = imported_pids | fetch_obj[:imported_pids]
              @items.flatten! 
              create_items(@items, @store, category, created_at) 
            end
          else
            @items = []
            fetch_obj = fetch_page_data(response[:productCategoryFacetedSearch][:productCategory][:childCategories], imported_pids)
            @items << [fetch_obj[:items]]
            imported_pids = imported_pids | fetch_obj[:imported_pids]
            @items.flatten! 
            create_items(@items, @store, category, created_at) 
          end
        else
          @items = []
          fetch_obj = fetch_page_data(response[:productCategoryFacetedSearch][:productCategory], imported_pids)                    
          @items << [fetch_obj[:items]]
          imported_pids = imported_pids | fetch_obj[:imported_pids]
          @items.flatten! 
          create_items(@items, @store, category, created_at) 
        end        
        # @items.flatten! 
        # create_items(@items, @store, category, created_at)                         
      end
      complete_item_creation(@store)
    end

    def get_prices(item)
      if item[:mupMessage].present?
        price = item[:mupMessage]
        msrp = item[:price][:currentMaxPrice]
      else
        price = item[:price][:currentMinPrice]
        msrp = item[:price][:currentMaxPrice]
      end
      {price: price, msrp: msrp}
    end

    def get_image_url(pid)
      result = Curl::Easy.perform(self::PRODUCT_RESOURCE_URL.gsub("%%pid%%", pid)) do |curl|
        curl.follow_location = true
        curl.enable_cookies = true
      end
      product_js = result.body.gsub(/\n+|\r+/, "\n").squeeze("\n").strip.gsub("^", "")
      position = product_js.scan(PRODUCT_OCCURANCE_REGEX).flatten.index(pid)
      d_regex = Regexp.new(GENERIC_IMAGE_REGEX.gsub("%%pid%%", pid).gsub("%%position%%", position.to_s), true)
      if product_js =~ d_regex
        "http://#{self::DOMAIN}#{product_js.match(d_regex)[1].gsub("'","").gsub(/\s*/, "")}"
      end
    end

    def fetch_page_data(child_categories, imported_pids)
      child_cid = child_categories[:businessCatalogItemId]
      items = child_categories[:childProducts]
      if items.present? && !items.is_a?(Array)
        items = [items]
      end
      data = []
      unless items.nil?
        items.each do |item|        
          begin
            pid = item[:businessCatalogItemId]            
            url = self::PRODUCT_URL.gsub("%%PID%%", pid).gsub("%%child_cid%%", child_cid)
            next if imported_pids.include?(pid)

            prod_obj = parse_product_detail(url, pid)          
            color_infos = prod_obj[:prod_info]
            imported_pids = imported_pids | prod_obj[:imported_pids]
            data << {
              name: item[:name],
              url: url,
              price: get_prices(item)[:price],
              msrp: get_prices(item)[:msrp],
              image_url: get_image_url(pid),
              import_key: "#{self::IMPORT_KEY_PREFIX}#{child_cid}_#{pid}"
            }.merge(color_infos)
            
          rescue Exception => e
            puts '^' * 40
            puts "ERROR: Failed to fully scrape item with url: #{url}"
            puts "Error: #{e}"
            puts '^' * 40
          end          
        end        
      end
      { items: data, imported_pids: imported_pids }
    end

    def category_api_url(category)
      if category.url =~ REG_EX
        cid = category.url.match(REG_EX)[1]
        style = category.url.match(REG_EX)[2]
        url = self::API_URL.gsub("%%cid%%", cid)
        url = style.present? ? url.gsub("%%style%%", style) : url.gsub("&style=%%style%%", "")
        url
      end
    end

    def has_more_info
      true
    end
    
    def parse_product_detail(product_detail_url, pid)
      begin         
        b = Watir::Browser.new(:phantomjs)
        if product_detail_url.include?('vid=')
          product_detail_url = product_detail_url.gsub(/&vid=\d/, "&vid=1")
        else
          product_detail_url = "#{product_detail_url}&vid=1"
        end
        b.goto product_detail_url        
        b.window.resize_to(1000, 800)
        product_doc = Nokogiri::HTML(b.html)
        
        name = product_doc.xpath('//span[@class="productName"]').try(:text).strip
        desc = product_doc.xpath('//div[@id="tabWindow"]/ul[position()=1]/li').try(:map, &:text).join(' ')
        
        if product_doc.xpath('//div[@id="swatchContent"]//strike[position()=1]').present?
          msrp = product_doc.xpath('//div[@id="swatchContent"]//strike[position()=1]').try(:text).strip
        end

        resource_obj = get_colors_map_from_js(pid)

        color_images_map = resource_obj[:color_images_map]
        imported_pids = resource_obj[:pids]

        more_info = product_doc.xpath('//div[@id="tabWindow"]/ul[position()>1]/li').try(:children).try(:map, &:text)
        
        color_infos = []          

        item_import_key = "#{self::IMPORT_KEY_PREFIX}#{pid}"        
        
        import_keys = [item_import_key]
        color_info = {}
        
        swatch_tags = product_doc.xpath('//div[@id="colorSwatchContent"]/input[contains(@id, "colorSwatch_")]')
      
        ordered_swatches = order_swatches(swatch_tags)        
        ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
          color_info = {}
          if (swatch_tag_index > 0)     
            if b.element(xpath: '//div[@id="variantButtons"]//li[text()="regular"]').present?
              b.element(xpath: '//div[@id="variantButtons"]//li[text()="regular"]').click
            end            
            b.input(src: swatch_tag['src']).click
            product_doc = Nokogiri::HTML(b.html)
          end
          
          
          color_info[:sizes] = []
          color_info[:color_item_url] = product_detail_url

          sizes_tags = product_doc.xpath('//div[@id="sizeDimension1Swatches"]/button')
          if sizes_tags.present?
            sizes_tags.each do |size_tag|
              next if size_tag['class'].include?('selectedSoldOut')
              next if size_tag['class'].include?('soldOut')              
              color_info[:sizes] << "#{size_tag.text.strip}"              
            end          
          end

          color_info[:image_url] = swatch_tag['src']

          color_info[:color] = swatch_tag['alt'].gsub('product image', '').strip

          color_id = color_info[:color].downcase.split(' ').join('_')
          color_info[:import_key] = "#{item_import_key}_#{color_id}"
          
          if color_images_map[color_info[:color]].present?
            color_info[:images] = color_images_map[color_info[:color]].map{ |k, v| "http://#{self::DOMAIN}#{v}"}
          else
            color_info[:images] = []
          end
          color_infos << color_info          
        end
        
        ## If Tall Tag present
        if b.element(xpath: '//div[@id="variantButtons"]//li[text()="tall"]').present?        
          b.execute_script('jQuery("div#sizeDimension1Swatches").html("");')
          b.element(xpath: '//div[@id="variantButtons"]//li[text()="tall"]').click
          b.element(xpath: '//div[@id="sizeDimension1Swatches"]/button').wait_until_present
          product_doc = Nokogiri::HTML(b.html)
          swatch_tags = product_doc.xpath('//div[@id="colorSwatchContent"]/input[contains(@id, "colorSwatch_")]')
        
          ordered_swatches = order_swatches(swatch_tags)        
          ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
            color_info = {}
            if (swatch_tag_index > 0)
              b.execute_script('jQuery("div#imageThumbs").html("");')                           
              b.input(src: swatch_tag['src']).click
              b.element(xpath: '//div[@id="imageThumbs"]/input').wait_until_present
              product_doc = Nokogiri::HTML(b.html)
            end
            
            
            color_info[:sizes] = []
            color_info[:color_item_url] = product_detail_url

            sizes_tags = product_doc.xpath('//div[@id="sizeDimension1Swatches"]/button')
            if sizes_tags.present?
              sizes_tags.each do |size_tag|
                next if size_tag['class'].include?('selectedSoldOut')
                next if size_tag['class'].include?('soldOut')              
                color_info[:sizes] << "#{size_tag.text.strip} Tall"              
              end          
            end
            
            color_info[:image_url] = swatch_tag['src']

            color_info[:color] = swatch_tag['alt'].gsub('product image', '').strip

            color_id = color_info[:color].downcase.split(' ').join('_')
            color_info[:import_key] = "#{item_import_key}_#{color_id}"

            if color_images_map[color_info[:color]].present?
              color_info[:images] = color_images_map[color_info[:color]].map{ |k, v| "http://#{self::DOMAIN}#{v}"}
            else
              color_info[:images] = []
            end
            idx = 0
            color_infos.each do |c_val|
              if c_val[:import_key] == color_info[:import_key]
                break                
              end
              idx = idx + 1
            end
            if color_infos.length == idx #new color
              color_infos[idx] = color_info
            else
              color_infos[idx][:sizes] = color_infos[idx][:sizes] | color_info[:sizes]                
            end
          end
        end

        ## If Petite Tag present
        if b.element(xpath: '//div[@id="variantButtons"]//li[text()="petite"]').present?      
          b.execute_script('jQuery("div#sizeDimension1Swatches").html("");')
          b.element(xpath: '//div[@id="variantButtons"]//li[text()="petite"]').click
          b.element(xpath: '//div[@id="sizeDimension1Swatches"]/button').wait_until_present
          
          product_doc = Nokogiri::HTML(b.html)
          swatch_tags = product_doc.xpath('//div[@id="colorSwatchContent"]/input[contains(@id, "colorSwatch_")]')
        
          ordered_swatches = order_swatches(swatch_tags)        
          ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
            color_info = {}
            if (swatch_tag_index > 0)               
              b.execute_script('jQuery("div#imageThumbs").html("");')                           
              b.input(src: swatch_tag['src']).click
              b.element(xpath: '//div[@id="imageThumbs"]/input').wait_until_present
              product_doc = Nokogiri::HTML(b.html)
            end
            
            
            color_info[:sizes] = []
            color_info[:color_item_url] = product_detail_url
            
            sizes_tags = product_doc.xpath('//div[@id="sizeDimension1Swatches"]/button')
            if sizes_tags.present?
              sizes_tags.each do |size_tag|
                next if size_tag['class'].include?('selectedSoldOut')
                next if size_tag['class'].include?('soldOut')              
                color_info[:sizes] << "#{size_tag.text.strip} Petite"              
              end          
            end
            
            color_info[:image_url] = swatch_tag['src']

            color_info[:color] = swatch_tag['alt'].gsub('product image', '').strip

            color_id = color_info[:color].downcase.split(' ').join('_')
            color_info[:import_key] = "#{item_import_key}_#{color_id}"
            if color_images_map[color_info[:color]].present?
              color_info[:images] = color_images_map[color_info[:color]].map{ |k, v| "http://#{self::DOMAIN}#{v}"}
            else
              color_info[:images] = []
            end
            idx = 0
            color_infos.each do |c_val|
              if c_val[:import_key] == color_info[:import_key]
                break                
              end
              idx = idx + 1
            end
            if color_infos.length == idx #new color
              color_infos[idx] = color_info
            else
              color_infos[idx][:sizes] = color_infos[idx][:sizes] | color_info[:sizes]                
            end            
          end
        end

      rescue Exception => e
        puts '^' * 40
        puts "ERROR: Failed to fully scrape item with url: #{product_detail_url} on Gap"
        puts "Error: #{e}"
        puts '^' * 40
      end
      close_browser(b)
      all_sizes = []
      color_infos.each do |color_info|
        all_sizes << color_info[:sizes]
      end
      prod_info = {         
        description: desc,         
        size: all_sizes.flatten.compact.uniq, 
        more_info: more_info,           
        import_key: item_import_key,
        colors: color_infos
      }
      prod_info = prod_info.merge(msrp: msrp) if msrp
      { prod_info: prod_info, imported_pids: imported_pids }
    end

    def order_swatches(swatch_tags)
      ordered_swatches = []
      color_ids = []
      if swatch_tags.count > 1
        selected_index = -1
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
          next unless swatch_tag['class'].include?('selected')
          selected_index = swatch_tag_index
          ordered_swatches << swatch_tag
          color_ids << swatch_tag['id'].match(/colorSwatch_(\d+)/)[1]
          break          
        end
        
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
          next if selected_index == swatch_tag_index
          color_id = swatch_tag['id'].match(/colorSwatch_(\d+)/)[1]
          unless color_ids.include? color_id
            ordered_swatches << swatch_tag
            color_ids << color_id
          end          
        end
      else
        ordered_swatches = swatch_tags
      end
      ordered_swatches
    end

    def get_colors_map_from_js(pid)
      result = Curl::Easy.perform(self::PRODUCT_RESOURCE_URL.gsub("%%pid%%", pid)) do |curl|
        curl.follow_location = true
        curl.enable_cookies = true
      end

      matches = result.body.scan(/arrayVariantStyleColors\[(\d+)\]\.styleColorImagesMap = (\{.*?\});/)

      pids = result.body.scan(/objP\.StyleColor\("(\d+?)"/)
      pids.flatten!

      color_images_map = {}
      matches.each do |match|
        color_images_map[match[0]] = ExecJS.eval(match[1])
      end

      matches = result.body.scan(/arrayVariantStyleColors\[(\d+)\] = new objP\.StyleColor\("\d+","(.*?)"/)
      color_names_map = {}
      matches.each do |match|
        color_names_map[match[0]] = match[1].strip
      end
      
      color_images_map.each do |color_id, color_images|        
        color_images.each do |key, image|
          if key == 'AV9_Z' #Video Image
            color_images_map[color_id].delete(key)
            next
          end            
          next if key.include?('_Z') || key == 'Z'

          color_images_map[color_id].delete(key)
        end
      end
      rlt = {}
      color_images_map.each do |color_id, color_images|
        rlt[color_names_map[color_id]] = color_images
      end
      
      {color_images_map: rlt, pids: pids }     
    end

  end
end