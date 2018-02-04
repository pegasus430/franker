class Aldo < StoreAPI
  class << self
    def store_items
      @store = Store.find_by(name: "Aldo")
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category|    
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Aldo Category URL : #{category.url}"
          @items = fetch_wf_data(Nokogiri::HTML(open(category.url, 'User-Agent' => 'DoteBot')))
          @items.flatten!
          create_items(@items, @store, category, created_at)
        end        
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      desc_item = item.css('.price-container')
      msrp = desc_item.at_css('.strikethrough').try(:text).try(:strip) || ""
      price = desc_item.at_css('.price').try(:text).try(:strip)
      { msrp: msrp, price: price}
    end

    def image_url_for(item)
      "http:#{item.at_css('a > img').attr('src').gsub("RG_160", "RG")}"
    end

    def url_for(item)
      "http://www.aldoshoes.com#{item.at_css('> a').attr('href')}"
    end

    def name_for(item)
      item.at_css('.title').text
    end

    def fetch_wf_data(page_doc)
      data = []
      page_doc = page_doc.dup
      page_doc.css('.product-tile-row > .product-tile').each do |item|
        next if item.attr('class').split(" ").map(&:downcase).include?("promo")
        name = name_for(item)
        image_url = image_url_for(item)
        import_key = "aldo_#{item.at_css('a > img').attr('id')}"
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
        product_doc = Nokogiri::HTML(b.html)

        desc = product_doc.xpath('//div[@class="description"]').text.strip
        color_info = {}
        swatche_tags = product_doc.xpath('//div[@class="attribute-swatches"]//a[contains(@class, "colorVariant")]')
        # DO scrapping unselelected colors
        selected_swatch_index = -1
        swatche_tags.each_with_index do |swatch_tag, swatch_tag_index|
          
          next unless swatch_tag.parent['class'].include?('active')                        
          color_info = {}
          sizes_tags = product_doc.xpath('//div[contains(@class, "attribute-sizes")]/p[@class="size"]')       
          color_info[:sizes] = []

          sizes_tags.each do |size_tag|
            # next if size_tag.parent['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end
          
          color_info[:color] = swatch_tag.xpath('.//img')[0]['alt']
          color_info[:color_item_url] = "http://www.aldoshoes.com#{swatch_tag['href']}"

          color_id = swatch_tag['href'].split('/')[-1].split('-')[-1]

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//ul[@id="carousel_alternate"]/li/span[contains(@class, "thumb")]//img/@src').map(&:text)
          
          if swatch_tag.xpath('.//img').present?
            color_info[:image_url] = swatch_tag.xpath('.//img/@src').text            
          else
            color_info[:image_url] = image_urls[0]
          end
          unless color_info[:image_url].include?('http')
            color_info[:image_url] = 'http:' + color_info[:image_url]
          end

          color_info[:images] = []
          image_urls.each do |image_url|            
            image_url = "http:#{image_url}" unless image_url.include?('http')
            color_info[:images] << image_url.gsub('_70.', ".")
          end
                   
          color_infos << color_info
        end

        swatche_tags.each_with_index do |swatch_tag, swatch_tag_index|
          next if swatch_tag.parent['class'].include?('active')            
          color_info = {}
          b.goto "http://www.aldoshoes.com#{swatch_tag['href']}"          
          product_doc = Nokogiri::HTML(b.html)

          sizes_tags = product_doc.xpath('//div[contains(@class, "attribute-sizes")]/p[@class="size"]')       
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            # next if size_tag.parent['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end          
          color_info[:color] = swatch_tag.xpath('.//img')[0]['alt']
          color_info[:color_item_url] = "http://www.aldoshoes.com#{swatch_tag['href']}"

          color_id = swatch_tag['href'].split('/')[-1].split('-')[-1]

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//ul[@id="carousel_alternate"]/li/span[contains(@class, "thumb")]//img/@src').map(&:text)
          
          if swatch_tag.xpath('.//img').present?
            color_info[:image_url] = swatch_tag.xpath('.//img/@src').text            
          else
            color_info[:image_url] = image_urls[0]
          end
          unless color_info[:image_url].include?('http')
            color_info[:image_url] = 'http:' + color_info[:image_url]
          end

          color_info[:images] = []
          image_urls.each do |image_url|            
            image_url = "http:#{image_url}" unless image_url.include?('http')
            color_info[:images] << image_url.gsub('_70.', ".")
          end
                   
          color_infos << color_info
        end
      rescue Exception => e
        puts '^' * 40
        puts "Encounted error #{e} while scraping secondary images on Aldo scraper"
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