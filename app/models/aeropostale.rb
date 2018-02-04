class Aeropostale < StoreAPI
  DOMAIN  = "www.aeropostale.com"

  class << self
    def store_items
      @store = Store.where(name: "Aeropostale").last
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category|
        puts "Aeropostale Category URL : #{category.url}"
        next if category.url.nil? || category.url == "NA" || category.url.empty?        
        cat_doc = Nokogiri::HTML(open(category.url))
        product_detail_urls = parse_products(cat_doc)
        total_page = get_total_page(cat_doc)
        items = []
        
        cur_page = 0
        while cur_page < total_page          
          cur_page = cur_page + 1
          if cur_page > 1
            cat_doc = Nokogiri::HTML(open("#{category.url}&page=#{cur_page}"))
          end
          product_detail_urls = product_detail_urls | parse_products(cat_doc)
        end        
        puts "#{category.name} CNT: #{product_detail_urls.count}, P: #{total_page}"

        product_detail_urls.each do |product_detail_url|          
          product_sku =  product_detail_url.match(/productId=(\d+)/)[1]              
          prod_info = parse_product_detail(product_detail_url)
          items << prod_info[:items]
        end
        items.flatten!
        create_items(items, @store, category, created_at)
      end
      
      complete_item_creation(@store)
    end
    
    def has_more_info
      true
    end

    def parse_products(category_doc)
      category_doc.xpath('//div[contains(@class, "details-content")]/h4/a/@href').map(&:value)
    end 
    
    def parse_product_detail(product_detail_url)    
      begin
        unless product_detail_url.include?('http')
          product_detail_url = "http://#{DOMAIN}#{product_detail_url}"
        end
        b = Watir::Browser.new(:phantomjs)          
        b.goto product_detail_url
        product_doc = Nokogiri::HTML(b.html)
        
        name = product_doc.xpath('//div[@id="content"]/div[@class="right"]/h2').try(:text).strip
        desc = product_doc.xpath('//div[@id="content"]/div[@class="right"]/div[@class="product-description"]').text.gsub('<br>', '\n').strip
        
        price_tags = product_doc.xpath('//div[@id="content"]/div[@class="right"]/ul[@class="price"]/li')        
        price = ''
        msrp = ''
        price_tags.each do |price_tag|
          next unless price_tag['class'] && price_tag['class'].include?('now')
          price = price_tag.text.strip.match('([\d\.]+)')[1]
          break
        end
        price_tags.each do |price_tag|
          next if price_tag['class'] && price_tag['class'].include?('now')
          msrp = price_tag.text.strip.match('([\d\.]+)')[1]          
          break
        end

        msrp = price unless msrp

        more_info = []

        image_url = product_doc.xpath('//meta[@property="og:image"]/@content').text
        secondary_images = []

        color_infos = []          

        product_sku = product_detail_url.match(/productId=(\d+)/)[1]
        item_import_key = "aeropostale_#{product_sku}"
        
        import_keys = []
        color_info = {}
        
        swatch_tags = product_doc.xpath('//ul[contains(@class, "swatches")]/li/a')
        if swatch_tags.present?          
          selected_swatch_tag = product_doc.xpath('//div[contains(@class, "color-variations-thumb-color")][contains(@class, "active")]/a')
          ordered_swatches = order_swatches(swatch_tags)
          
          ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
            color_info = {}
            if (swatch_tag_index > 0)
              b.a({name: swatch_tag['name']}).click              
              product_doc = Nokogiri::HTML(b.html)              
            end

            sizes_tags = product_doc.xpath('//select[@name="prod_0"]/option')
            color_info[:sizes] = []

            color_info[:color_item_url] = product_detail_url

            if sizes_tags.present?
              sizes_tags.each do |size_tag|
                next unless size_tag['value'].present?
                color_info[:sizes] << size_tag.text.strip
              end
            else              
              one_size = product_doc.text.match(/sDesc: "(.+)"/)[1] rescue nil
              if one_size
                color_info[:sizes] = [one_size]
              else
                color_info[:sizes] = ["One Size"]
              end
            end

            image_urls = []
            image_tags = product_doc.xpath('//ul[@id="altimages"]/li/a/img')
            image_tags.each do |image_tag|
              next if image_tag.parent.parent['style'] == 'display: none;'
              image_urls << image_tag['src']
            end
            
            if image_urls.empty?
              image_urls << product_doc.xpath('//div[@id="zoomIn"]/img/@src').text.gsub('t386x450.jpg', "enh-z5.jpg")
            end            

            color_info[:image_url] = "http://#{DOMAIN}" + swatch_tag.xpath('.//img/@src').text
            color_info[:color] = swatch_tag['title'].strip

            color_id = swatch_tag['name'].split('|')[-1]
            color_info[:import_key] = "#{item_import_key}_#{color_id}"

            color_info[:images] = []          
            image_urls.each do |image_url|
              color_info[:images] <<  "http://#{DOMAIN}" + image_url.gsub('t76x88.jpg', "enh-z5.jpg")
            end     
            color_infos << color_info
          end
        end

      rescue Exception => e
        puts '^' * 40
        puts "ERROR: Failed to fully scrape item with url: #{product_detail_url}"
        puts "Error: #{e}"
        puts '^' * 40
        close_browser(b)
        return {items: [], other_import_keys: []}
      end
      
      all_sizes = []
      color_infos.each do |color_info|
        all_sizes << color_info[:sizes]
      end
      close_browser(b)
      
      return {items: [{ 
        name: name,
        url: product_detail_url,
        price: price,
        msrp: msrp,
        image_url: image_url,          
        description: desc, 
        secondary_images: secondary_images,
        size: all_sizes.flatten.compact.uniq, 
        more_info: more_info,
        import_key: item_import_key,
        colors: color_infos
      }], other_import_keys: []}

    end

    def get_total_page(category_doc)
      page_tags = category_doc.xpath('//div[@class="pagination"][position()=1]/ul/li/a')
      if page_tags.present?
        total_page = 1
        page_tags.each do |page_tag|
          if page_tag.text.strip.to_i > 0
            total_page = page_tag.text.strip.to_i
          end
        end        
      else
        total_page = 1
      end
      total_page
    end

    def order_swatches(swatch_tags)
      ordered_swatches = []
      color_ids = []
      if swatch_tags.count > 1
        selected_index = -1
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
          next unless swatch_tag.parent['class'].include?('active')
          selected_index = swatch_tag_index
          ordered_swatches << swatch_tag
          color_ids << swatch_tag['name']
          break          
        end
        
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
          next if selected_index == swatch_tag_index
          color_id = swatch_tag['name']
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

    def image_url_from(row)
      image_url = row.image_url.gsub("t130x152.jpg", "enh-z5.jpg").
                                gsub("t382x651.jpg", "enh-z5.jpg").
                                gsub("outfit_t143x167.jpg", "outfit_t382x651.jpg")
    end

    def import_key_for(row)
      "aeropostale_#{row.image_thumb_url.split("-")[1].gsub(/[^\d]/, '')}"
    end

  end

end