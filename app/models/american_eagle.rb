class AmericanEagle < StoreAPI
  DOMAIN  = "http://www.ae.com"
  PARSE_REGEX = /<script type=\"text\/javascript\">\n?var\scategory_json\s=\s?(.*)?;(\w|\W)*?<\/script>/i
  IMAGE_URL_TEMPLATE = "http://pics.ae.com/is/image/aeo/%%product_id_color_id%%_f?fit=crop&wid=1024&hei=1280&qlt=100,0"
  PRODUCT_URL = "#{DOMAIN}/web%%defaultURL%%?productId=%%product_id_color_id%%"

  TYPE_OF_PRODUCT_VIEW = {
    wide: ['Jackets and Outerwear', 'Sweaters', 'Hoodies and Sweatshirts', 'Shirts', 'Tees', 'Graphic Tees', 'Jeans', 'Polos', 'Tank Tops', 'Pants', 'Joggers and Lounge', 'Leggings and Yoga', 'Skirts', 'Shorts', 'Tops', 'Dresses', 'Bottoms'],
    high: ['Shoes', 'Hats Gloves Scarves',  'Fashion Scarves', 'Bags', 'Belts', 'Jewelry', 'Hair Accessories', 'Sunglasses', 'Gifts', 'Accessories']
  }
  
  class << self
    def store_items
      @store = Store.where(name: "American Eagle").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|        

        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"
          begin
            body = Curl.get(category.url).body
            if body =~ PARSE_REGEX
              json = JSON.parse(body.match(PARSE_REGEX)[1])
            end
          rescue Exception => e
            Sidekiq.logger.info "^" * 40
            Sidekiq.logger.info "Error At Opening Category URL: #{category.url}"
            Sidekiq.logger.info "Error: #{e}"
            Sidekiq.logger.info "^" * 40
          end
          if json.present?
            begin
              @items = fetch_ae_data(json, category)
              @items.flatten!
            rescue Exception => e
              Sidekiq.logger.info "^" * 40
              Sidekiq.logger.info "Error: #{e}"
              Sidekiq.logger.info "Error At Items Fetching for URL: #{category.url}"
              Sidekiq.logger.info "Message:\n #{e.message}"
              Sidekiq.logger.info "backtrace:\n #{e.backtrace.join('\n')}"
              Sidekiq.logger.info "^" * 40
              Airbrake.notify_or_ignore(
                e,
                parameters: {},
                cgi_data: ENV.to_hash
              )
            end
            create_items(@items, @store, category, created_at)
          end
        end        
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      { price: item["salePrice"], msrp: item["listPrice"] }
    end

    def image_url_for(item)
      IMAGE_URL_TEMPLATE.gsub("%%product_id_color_id%%", item["firstAvailableColorPrdId"])
    end

    def url_for(item)
      PRODUCT_URL.gsub("%%defaultURL%%", item["defaultURL"]).gsub("%%product_id_color_id%%", item["firstAvailableColorPrdId"])
    end

    def fetch_ae_data(json, category)
      json = json.dup.with_indifferent_access
      data = []
      import_keys = []
      json["availablePrds"].each do |item|
        import_key = "american_eagle_#{item.first}"
        if import_keys.include? import_key
          next
        end
        item = item.last.dup
        prices = prices_for(item)
        name = CGI.unescapeHTML item["prdName"]
        image_url = image_url_for(item)
        url = url_for(item)    
        if TYPE_OF_PRODUCT_VIEW[:wide].include?(category.name)
          more_info, other_import_keys = get_more_infos_for_wide_view(url, import_key)
        else
          more_info, other_import_keys = get_more_infos_for_high_view(url, import_key)
        end
        if more_info[:colors].empty?
          unless TYPE_OF_PRODUCT_VIEW[:wide].include?(category.name)
            more_info, other_import_keys = get_more_infos_for_wide_view(url, import_key)
          else
            more_info, other_import_keys = get_more_infos_for_high_view(url, import_key)
          end
        end

        import_keys << other_import_keys
        
        data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item)).merge(more_info)
      end
      data
    end
    
    def has_more_info
      true
    end
    
    def get_more_infos_for_wide_view(product_url, item_import_key)
      begin
        b = Watir::Browser.new(:phantomjs)
        b.goto product_url
        product_doc = Nokogiri::HTML(b.html)

        desc = product_doc.xpath('//div[@class="equity-details-description"]').text
        more_info = product_doc.xpath('//div[@class="details-list-div"]/ul[@class="details-list"]').try(:children).try(:map, &:text)

        color_infos = []
        import_keys = [item_import_key]
        color_info = {}
        swatch_tags = product_doc.xpath('//div[contains(@class, "swatches")][contains(@class, "maxi")]/a[contains(@class, "swatch_link")]')
        
        ordered_swatches = order_swatches(swatch_tags)
        
        ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|          
          color_info = {}
          if (swatch_tag_index > 0)
            b.execute_script("$('ul#main-product-thumbnail-images').html('');")
            color_id = swatch_tag['data-colorid']

            b.execute_script('$("a[data-colorid=\'' + color_id + '\']").trigger("click");')
            unless b.element(:xpath => "//ul[@id='main-product-thumbnail-images']/li").present?
              b.goto "#{DOMAIN}#{swatch_tag['href']}"
              product_id = swatch_tag['href'].match(/productId=(.*)_#{color_id}/)[1]
              import_key = "american_eagle_#{product_id}"
              unless import_keys.include? import_key
                import_keys << import_key
              end
            end
            product_doc = Nokogiri::HTML(b.html)
          end
          
          image_url = product_doc.xpath("//a[@data-colorid='#{swatch_tag['data-colorid']}']/img/@src")[0].text
          color_info[:image_url] = image_url
          
          unless color_info[:image_url].include?('http')
            color_info[:image_url] = "http:#{color_info[:image_url]}"
          end

          sizes_tags = product_doc.xpath('//select[contains(@class, "sel_field sizeField")]/option')
          color_info[:sizes] = []
          if sizes_tags.present?
            sizes_tags.each do |size_tag|
              next if size_tag.text.downcase.include?('out of stock')
              next if size_tag.text.strip.empty?
              color_info[:sizes] << size_tag.text.gsub('- Online only.', '').strip
            end
          else
            color_info[:sizes] = ['One Size']
          end
          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = "#{DOMAIN}#{swatch_tag['href']}"        
          
          color_info[:import_key] = "#{item_import_key}_#{swatch_tag['data-colorid']}"
          image_urls = product_doc.xpath('//ul[@id="main-product-thumbnail-images"]/li/img/@src').map(&:text)
          color_info[:images] = []          
          image_urls.each do |image_url|
            color_info[:images] <<  "http:" + image_url.gsub("?$pdp78$", "?fit=stretch&qlt=84,0&id=iigqa1&hei=620&fmt=jpg")        
          end     
          color_infos << color_info
        end
      rescue Exception => e
        puts '^' * 40
        puts "ERROR: Failed to fully scrape item with url: #{product_url}"
        puts "Error: #{e}"
        puts '^' * 40
      end
      close_browser(b)

      return { colors: color_infos, description: desc, size: color_info[:sizes], more_info: more_info }, import_keys
    end

    def get_more_infos_for_high_view(product_url, item_import_key)
      begin
        b = Watir::Browser.new(:phantomjs)      
        b.goto product_url
        product_doc = Nokogiri::HTML(b.html)

        desc = product_doc.xpath('//div[@class="linePadding leadingEquity"]').text
        more_info = product_doc.xpath('//div[@class="addlEquity"]/ul[@class="equityBullets firstSet"]').try(:children).try(:map, &:text)

        color_infos = []
        color_info = {}
        import_keys = [item_import_key]
        swatch_tags = product_doc.xpath('//div[contains(@class, "swatches")]/a[contains(@class, "swatch_link")]')
      
        ordered_swatches = order_swatches(swatch_tags)
        ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
          color_info = {}
          if (swatch_tag_index > 0)
            b.execute_script("$('.prodImages .productSet').html('');")
            color_id = swatch_tag['data-colorid']
          
            b.execute_script('$("a[data-colorid=\'' + color_id + '\']").trigger("click");')          
            unless b.element(:xpath => "//div[@class='productSet']/span").present?
              b.goto "#{DOMAIN}#{swatch_tag['href']}"
              product_id = swatch_tag['href'].match(/productId=(.*)_#{color_id}&/)[1]
              import_key = "american_eagle_#{product_id}"
              unless import_keys.include? import_key
                import_keys << import_key
              end
            end
            product_doc = Nokogiri::HTML(b.html)
          end
          
          image_url = product_doc.xpath("//a[@data-colorid='#{swatch_tag['data-colorid']}']/img/@src")[0].text
          color_info[:image_url] = image_url
          
          unless color_info[:image_url].include?('http')
            color_info[:image_url] = "http:#{color_info[:image_url]}"
          end 
          
          sizes_tags = product_doc.xpath('//div[@id="size_0"]/a')
          color_info[:sizes] = []
          if sizes_tags.present?
            sizes_tags.each do |size_tag|
              next if size_tag.text.strip.empty?
              next if size_tag['class'].include?('disabled')  ## if no stock
              color_info[:sizes] << size_tag['data-sizename']
            end
          end
          sizes_tags = product_doc.xpath('//div[@id="size_1"]/a')
          if sizes_tags.present?
            sizes_tags.each do |size_tag|
              next if size_tag.text.strip.empty?
              next if size_tag['class'].include?('disabled')  ## if no stock
              color_info[:sizes] << size_tag['data-sizename']
            end
          end
          
          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = "#{DOMAIN}#{swatch_tag['href']}"        
          
          color_info[:import_key] = "#{item_import_key}_#{swatch_tag['data-colorid']}"
          image_urls = product_doc.xpath('//div[contains(@class, "mainAreaImg")]//div[@class="productSet"]//img[@class="thumbNail"]/@src').map(&:text)
          color_info[:images] = []          
          image_urls.each do |image_url|
            color_info[:images] <<  "http:" + image_url.gsub(/wid=\d+/, "wid=1024").gsub(/hei=\d+/, "hei=800").gsub("&fit=crop", "")
          end          
          color_infos << color_info
        end
      rescue Exception => e
        puts '^' * 40
        puts "ERROR: Failed to fully scrape item with url: #{product_url}"
        puts "Error: #{e}"
        puts '^' * 40
      end
      close_browser(b)

      return { colors: color_infos, description: desc, size: color_info[:sizes], more_info: more_info }, import_keys
    end
    
    def order_swatches(swatch_tags)
      ordered_swatches = []
      color_ids = []
      if swatch_tags.count > 1
        selected_index = -1
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
          if swatch_tag['class'].include?('selected')
            selected_index = swatch_tag_index
            ordered_swatches << swatch_tag
            color_ids << swatch_tag['data-colorid']
            break
          end
        end
        
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
          if selected_index != swatch_tag_index
            color_id = swatch_tag['data-colorid']
            unless color_ids.include? color_id
              ordered_swatches << swatch_tag
              color_ids << color_id
            end
          end
        end
      else
        ordered_swatches = swatch_tags
      end
      
      ordered_swatches
    end
    
  end
end