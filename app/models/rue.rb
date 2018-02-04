class Rue < StoreAPI
  class << self
    def store_items
      @store = Store.find_by(name: "Rue 21")
      @categories = @store.categories.external.where(id: 8301)
      created_at = DateTime.now
      number_of_items_to_retrieve_per_page = 16
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"
          @items = []
          @total = 0
          @index = 0
          begin
            begin
              @page_data = Nokogiri::HTML(open(category.url.try(:strip) + "?No=#{@index*number_of_items_to_retrieve_per_page}", 'User-Agent' => 'DoteBot'))
            rescue Exception => e
              puts "^" * 40
              puts "Error: #{e}"
              puts "Error At Opening Category URL: #{category.url}"
              puts "^" * 40
              break
            end
            @total = @page_data.at_css(".product-count").text.strip.to_i if @total == 0
            @items << fetch_tb_data(@page_data, category)            
            @index = @index + 1
          end while (@index*number_of_items_to_retrieve_per_page) < @total
          
          create_items(@items.flatten, @store, category, created_at)
        end        
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      msrp = item.at_css(".list-price").try(:text).to_s.strip
      price = item.at_css(".current-price").text.strip
      price = price[1] if price.split("-").size > 1
      promo = item.at_css(".promo-title").try(:text).try(:squish)
      if promo.present? and (promo.split[0..1].join(" ") ==  "SALE PRICE")
        msrp = price
        price = promo.split[-1]
      end
      { msrp: msrp, price: price}
    end

    def image_url_for(item)
      @images = item.at_css('.category-product-img a.product-link  img.product-image').attr("data-interchange").scan(/\[([^\]]*)\]/).flatten 
      if @images.size > 1 and @images[1].split(", ")[-1].to_s == "(retina)"
        "http:" + @images[1].split(", ")[0] #.gsub("$trb_grid_224x254$", "$trb_fullscreen$&fmt=jpeg")
      else
        "http:" + @images[0].split(", ")[0] #.gsub("$trb_grid_224x254$", "$trb_fullscreen$&fmt=jpeg")
      end       
    end

    def secondary_image_url_for(item)
      @images = item.at_css('.category-product-img a.product-link  img.product-image').attr("data-interchange").scan(/\[([^\]]*)\]/).flatten 
      if @images.size > 1
        "http:" + @images[1].split(", ")[0] #.gsub("$trb_grid_224x254$", "$trb_fullscreen$&fmt=jpeg")
      end
    end

    def url_for(item)
      "http://www.rue21.com/" + item.at_css(".category-product-img a.product-link").attr("href")
    end

    def name_for(item)
      item.at_css(".product-name").text.strip
    end

    def fetch_tb_data(page_doc, category)
      data = []
      products = page_doc.css('ul#product-grid li.category-product  .product-tile')
      products.each do |item|
        name = name_for(item)
        image_url = image_url_for(item)
        url = url_for(item)        
        import_key = "rue_21_#{url.split("/")[-1]}"
        color_infos = get_more_infos(url, import_key)
        data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item)).merge(color_infos)                
      end
      data
    end

    def has_more_info
      true
    end

    def get_more_infos(product_url, item_import_key)
      color_infos = []
      desc = ''
      more_info = []
      begin         
        b = Watir::Browser.new(:phantomjs)      
        b.goto product_url
        product_doc = Nokogiri::HTML(b.html)

        desc = product_doc.xpath('//span[@itemprop="description"]/p').text.strip
        more_info = product_doc.xpath('//span[@itemprop="description"]/ul').try(:children).try(:map, &:text)

        color_info = {}
        swatch_tags = product_doc.xpath('//ul[contains(@class, "product-sku-color")]/li[contains(@class, "product-sku-colors")]/a')      
        # DO scrapping unselelected colors 
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|          
          next unless swatch_tag['class'].include?('selected')
          
          color_info = {}
          
          sizes_tags = product_doc.xpath('//ul[contains(@class, "product-sku-size")]/li[contains(@class, "product-sku-sizes")]')
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            # next if size_tag.parent['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['data-original-title']
          color_info[:color_item_url] = product_url

          color_id = swatch_tag['id'].match(/color_(\d+)/)[1]

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          thumb_tag_styles = product_doc.xpath('//div[@id="swatches"]//div[contains(@class, "s7thumb")]/@style').map(&:text)          
          image_urls = thumb_tag_styles.map{|s| s.match(/background-image: url\((.*?)\)/)[1]}          

          color_info[:image_url] = swatch_tag['style'].match(/background: url\((.*?)\)/)[1] rescue nil          
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
          color_info = {}

          b.execute_script("$('div#swatches .s7thumb').remove();")
          b.a(id: swatch_tag['id']).click
          b.element(:xpath => "//div[@id='swatches']//div[contains(@class, 's7thumb')]").wait_until_present
          product_doc = Nokogiri::HTML(b.html)
          
          sizes_tags = product_doc.xpath('//ul[contains(@class, "product-sku-size")]/li[contains(@class, "product-sku-sizes")]')
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            # next if size_tag['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['data-original-title']
          color_info[:color_item_url] = product_url

          color_id = swatch_tag['id'].match(/color_(\d+)/)[1]

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          thumb_tag_styles = product_doc.xpath('//div[@id="swatches"]//div[contains(@class, "s7thumb")]/@style').map(&:text)          
          image_urls = thumb_tag_styles.map{|s| s.match(/background-image: url\((.*?)\)/)[1]} 
          color_info[:image_url] = swatch_tag['style'].match(/background: url\((.*?)\)/)[1] rescue nil
          
          unless color_info[:image_url]
            color_info[:image_url] = image_urls[0]
          end

          color_info[:images] = []
          image_urls.each do |image_url|                    
            color_info[:images] << image_url.gsub(/\?.*/, "?hei=800")
          end
                   
          color_infos << color_info
        end
      rescue Exception => e
        puts '^' * 40
        puts "Encounted error #{e} while scraping secondary images on Rue21 scraper"
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