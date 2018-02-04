class LillyPulitzer < StoreAPI
  class << self
    REGEX = /.*currentCategoryId=(\d*)?;.*pages=(\d*);/i
    
    def store_items
      @store = Store.find_by(name: "Lilly Pulitzer")
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Lilly Pulitzer Category URL : #{category.url}"
          @items = []
          currentIndex = 0
          pageSize = 16
          firstPageSize = 16
          begin
            url = category.url.match(/(.*?\d*\.uts).*/i)[1]
            url_1 = "#{url}?currentIndex=#{currentIndex}&pageSize=#{pageSize}&firstPageSize=#{firstPageSize}"
            items = fetch_lp_data(Nokogiri::HTML(open(url_1)))
            @items << items
            while items.size > 0
              currentIndex = currentIndex + firstPageSize
              url_1 = "#{url}?currentIndex=#{currentIndex}&pageSize=#{pageSize}&firstPageSize=#{firstPageSize}"
              items = fetch_lp_data(Nokogiri::HTML(open(url_1)))
              @items << items
            end
            @items.flatten!
            create_items(@items, @store, category, created_at)
          rescue Exception => e
            puts "^" * 40
            puts "Error encountered when scraping category: #{category.url}"
            puts "Error: #{e}"
            puts "^" * 40
          end          
        end

      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      msrp = ""
      price = item.at_css(".priceDisplay").at_css(".basePrice").text.strip
      { msrp: msrp, price: price}
    end

    def image_url_for(item)
      "http:#{item.at_css('.imageDisplay').at_css(".thumbLink img").attr("src").gsub("wid=186&hei=298", "wid=1024&hei=1080")}"
    end

    def url_for(item)
      "http://www.lillypulitzer.com/#{item.at_css(".thumbLink").attr("href")}"
    end

    def name_for(item)
      item.at_css('.productInfoWrapper').at_css('.thumbLink').text.strip
    end

    def fetch_lp_data(page_doc)
      data = []
      page_doc.css('.catalogEntityThumbnail').each do |item|
        name = name_for(item)
        image_url = image_url_for(item)
        import_key = "lilly_pulitzer_#{image_url.gsub(/[^\d]/, "")}"
        url = url_for(item)        
        color_infos = get_more_infos(url, import_key)
        data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item)).merge(color_infos)
      end
      data
    end
    def has_more_info
      true
    end    
    def get_more_infos(product_url, item_import_key)
      desc = ''
      more_info = []
      color_infos = []
      begin
        b = Watir::Browser.new(:phantomjs)
        b.goto product_url
        b.window.resize_to(800, 600)
        product_doc = Nokogiri::HTML(b.html)

        desc = product_doc.xpath('//div[@id="productDescription"]').text.strip      
        more_info = product_doc.xpath('//div[@id="moreProductInfo"]').try(:children).try(:map, &:text)
        if more_info.present? && !desc.present?
          more_info.each do |info|
            desc = "#{desc}\n#{info.strip}"
          end
          more_info = []
        end
        color_info = {}        
        swatch_tags = product_doc.xpath('//div[@id="swatchWrapProduct"]/dl[contains(@class, "color")]/dd/a')      
        # DO scrapping unselelected colors
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|          
          next unless swatch_tag['class'].include?('selected')
          
          color_info = {}

          sizes_tags = product_doc.xpath('//div[@id="swatchWrapProduct"]/dl[contains(@class, "size")]/dd/a')      
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|            
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = product_url

          color_id = swatch_tag['id'].match(/swatch(\d+)/)[1]

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@id="altImages"]//img/@src').map(&:text)          
          
          color_info[:image_url] = 'http:' + swatch_tag.xpath('.//span[@class="swatchImage"]/img/@src').text

          unless color_info[:image_url]
            color_info[:image_url] = image_urls[0]
          end

          color_info[:images] = []
          image_urls.each do |image_url|                    
            color_info[:images] << image_url.gsub(/\?.*/, "?hei=800")
          end
                   
          color_infos << color_info
        end

        swatch_tags.each_with_index do |swatch_tag, swatch_tags_index|
          next if swatch_tag['class'].include?('selected') 
          
          b.execute_script("$('ul.image-list').html('');")
          
          b.a(id: swatch_tag['id']).click
          b.element(:xpath => "//ul[@class='image-list']//img").wait_until_present
          product_doc = Nokogiri::HTML(b.html)

          color_info = {}

          sizes_tags = product_doc.xpath('//div[@id="swatchWrapProduct"]/dl[contains(@class, "size")]/dd/a')      
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|            
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = product_url

          color_id = swatch_tag['id'].match(/swatch(\d+)/)[1]

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@id="altImages"]//img/@src').map(&:text)          
          
          color_info[:image_url] = swatch_tag.xpath('.//span[@class="swatchImage"]/img/@src').text
          unless color_info[:image_url].include?('http')
            color_info[:image_url] = 'http:' + color_info[:image_url]
          end

          unless color_info[:image_url]
            color_info[:image_url] = image_urls[0]
          end

          color_info[:images] = []
          image_urls.each do |image_url|
            unless image_url.include?('http')
              image_url = "http:#{image_url}"
            end
            color_info[:images] << image_url.gsub(/\?.*/, "?hei=800")
          end
                   
          color_infos << color_info
        end
      rescue Exception => e
        puts '^' * 40
        puts "Encounted error #{e} while scraping Lilly Pulitzer items"
        puts '^' * 40
      end
      
      all_sizes = []
      color_infos.each do |color_info|
        all_sizes << color_info[:sizes]
      end

      close_browser(b)

      return { colors: color_infos, description: desc, size: all_sizes.flatten.compact.uniq, more_info: more_info }
    end

  end
end