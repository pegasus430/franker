class KateSpade < StoreAPI
  DOMAIN  = "http://www.katespade.com"
  IMAGE_REGEX = /(.*?)\?/i
  class << self
    def store_items
      @store = Store.where(name: "Kate Spade").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"
          begin
            main_doc = Nokogiri::HTML(open(category.url.try(:strip), 'User-Agent' => 'DoteBot'))
          rescue Exception => e
            Sidekiq.logger.info "^" * 40
            Sidekiq.logger.info "Error At Opening Category URL: #{category.url}"
            Sidekiq.logger.info "Error: #{e}"
            Sidekiq.logger.info "^" * 40
          end
          if main_doc.present?
            @items = []
            begin
              @items << fetch_kate_spade_data(main_doc)
              @items.flatten!
            rescue Exception => e
              Sidekiq.logger.info "^" * 40
              Sidekiq.logger.info "Error At Items Fetching for URL: #{category.url}"
              Sidekiq.logger.info "Error: #{e}"
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
    
    def has_more_info
      true
    end
    
    def prices_for(item)
      price = item.at_css('.price-sales').text.strip rescue nil
      msrp = item.at_css('.price-standard').text.strip rescue ""
      price ||= item.at_css('.product-price div').text.strip.split("-")[1].strip
      { price: price, msrp: msrp}
    end

    def image_url_for(item)
      image_url = item.at_css('.first-img').attr('data-baseurl')
      if image_url =~ IMAGE_REGEX
        "#{image_url.match(IMAGE_REGEX)[0]}?op_sharpen=0&resMode=sharp2&wid=1080&fmt=jpg"
      else
        image_url
      end
    end

    def fetch_kate_spade_data(page_doc)
      data = []
      page_doc.css('.product-tile').each do |item|
        begin
          image_url = image_url_for(item)
          name = item.at_css('.product-name').at_css('h2').text.strip.humanize
          url = item.at_css('.thumb-link').attr('data-full-url')
          import_key = "kate_spade_#{URI.parse(url).query.split('&')[0].split('_color')[0].parameterize}"
          more_info_dict = get_more_infos(url, import_key)
          data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item)).merge(more_info_dict)
        rescue Exception => e
          Airbrake.notify_or_ignore(
            e,
            parameters: {item: item},
            cgi_data: ENV.to_hash
          )
        end        
      end
      data
    end
    
    def get_more_infos(product_url, item_import_key)
      b = Watir::Browser.new(:phantomjs)      
      b.goto product_url
      product_doc = Nokogiri::HTML(b.html)

      desc = product_doc.xpath('//div[@id="tab2"]').text.strip
      more_info = product_doc.xpath('//div[@id="tab1"]/ul').try(:children).try(:map, &:text)

      color_infos = []
      color_info = {}
      swatche_tags = product_doc.xpath('//ul[contains(@class, "swatches Color")]/li/a')
      
      begin
        # DO scrapping unselelected colors
        selected_swatch_index = -1
        swatche_tags.each_with_index do |swatch_tag, swatch_tag_index|
          
          if swatch_tag.parent['class'].include?('selected') && swatch_tag_index == 0 && swatche_tags.length > 1
            selected_swatch_index = swatch_tag_index
            next
          end
          
          color_info = {}

          if swatche_tags.length > 1
            b.execute_script("$('ul.jcarousel-list').html('');")          
            b.a({href: swatch_tag['href'], class: 'swatchanchor'}).click
            b.element(:xpath => "//ul[contains(@class, 'jcarousel-list')]/li//img").wait_until_present
            product_doc = Nokogiri::HTML(b.html)
          end

          sizes_tags = product_doc.xpath('//ul[contains(@class, "swatches size")]/li/a')       
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            next if size_tag.parent['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = swatch_tag['href']

          color_id = swatch_tag.parent['data-value']

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@id="thumbnails"]//li[contains(@class, "thumb")]//img/@src').map(&:text)
          
          if swatch_tag.xpath('.//img').present?
            color_info[:image_url] = swatch_tag.xpath('.//img/@src').text
          else
            color_info[:image_url] = image_urls[0]
          end
          

          color_info[:images] = []
          image_urls.each do |image_url|                    
            color_info[:images] << image_url.gsub(/\?.*/, "?hei=800&fmt=jpg")
          end
                   
          color_infos << color_info
        end

        if selected_swatch_index == 0 && swatche_tags.length > 1
          swatch_tag = swatche_tags.first
          color_info = {}
          b.execute_script("$('ul.jcarousel-list').html('');")          
          b.a({href: swatch_tag['href'], class: 'swatchanchor'}).click
          b.element(:xpath => "//ul[contains(@class, 'jcarousel-list')]/li//img").wait_until_present
          product_doc = Nokogiri::HTML(b.html)

          sizes_tags = product_doc.xpath('//ul[contains(@class, "swatches size")]/li/a')       
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            next if size_tag.parent['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = swatch_tag['href']

          color_id = swatch_tag.parent['data-value']

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@id="thumbnails"]//li[contains(@class, "thumb")]//img/@src').map(&:text)
          
          if swatch_tag.xpath('.//img').present?
            color_info[:image_url] = swatch_tag.xpath('.//img/@src').text
          else
            color_info[:image_url] = image_urls[0]
          end
          
          color_info[:images] = []
          image_urls.each do |image_url|                    
            color_info[:images] << image_url.gsub(/\?.*/, "?hei=800&fmt=jpg")
          end
                   
          color_infos << color_info
        end
      rescue Exception => e
        puts '^' * 20
        puts "Encounted error #{e} while scraping secondary images on AmericanEagle scraper"
        puts '^' * 20
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