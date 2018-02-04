class WetSeal < StoreAPI
  class << self
    def store_items
      @store = Store.find_by(name: "Wet Seal")
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"
          @items = []
          start = 0
          size = 96
          main_doc = Nokogiri::HTML(open(category.url, 'User-Agent' => 'DoteBot')) rescue nil
          next if main_doc.nil?
          @items << fetch_ws_data(main_doc)
          while has_more_items?(main_doc) do
            main_doc = Nokogiri::HTML(open(main_doc.at_css('a.page-next').attr('href'), 'User-Agent' => 'DoteBot'))            
            @items << fetch_ws_data(main_doc)
          end
          @items.flatten!
          create_items(@items, @store, category, created_at)          
        end
      end
      
      complete_item_creation(@store)
    end

    def has_more_items?(main_doc)
      main_doc.at_css('a.page-next').present?
    end

    def prices_for(item)
      { msrp: "", price: item.at_css(".product-pricing .product-sales-price").text.try(:strip)}
    end

    def image_url_for(item)
      item.at_css("##{item.attr('data-itemid')}_1 img").attr('src').gsub("sw=282&sh=347", "sw=1080&sh=1024")
    end

    def url_for(item)
      item.at_css('a[itemprop="name"]').attr('href')
    end

    def name_for(item)
      item.at_css('a[itemprop="name"]').attr('title').try(:strip)
    end

    def fetch_ws_data(page_doc)
      data = []
      page_doc.css('.search-result-items li.grid-tile .product-tile').each do |item|
        next unless item.attr('itemtype') == "http://schema.org/Product"
        name = name_for(item)
        image_url = image_url_for(item)
        import_key = "wetseal_#{item.attr('data-itemid')}"
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

        desc = product_doc.xpath('//div[@id="tab2"]/p').text.strip
        more_info = product_doc.xpath('//div[@id="tab2"]/ul').try(:children).try(:map, &:text)
        price = product_doc.xpath('//span[@class="price-sales"]').try(:text).gsub('Now ', '')
        msrp = product_doc.xpath('//span[@class="price-standard"]').try(:text).gsub('Was ', '')

        color_info = {}
        swatch_tags = product_doc.xpath('//ul[contains(@class, "swatches Color")]/li/a')
        # DO scrapping unselelected colors
        selected_swatch_index = -1
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|          
          unless swatch_tag.parent['class'].include?('selected')            
            next
          end
          
          color_info = {}

          sizes_tags = product_doc.xpath('//ul[contains(@class, "swatches size")]/li/a')       
          color_info[:sizes] = []

          sizes_tags.each do |size_tag|
            next if size_tag.parent['class'].include?('unselectable')
            next if size_tag.parent['class'].include?('size-chart-link')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = swatch_tag['href']

          color_id = color_info[:color].split(' ').join('_').downcase

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@id="thumbnails"]//li[contains(@class, "thumb")]//img/@src').map(&:text)
          
          color_info[:image_url] = swatch_tag['style'].match(/background: url\((.*?)\)/)[1] rescue nil
          
          unless color_info[:image_url]
            color_info[:image_url] = image_urls[0]
          end

          color_info[:images] = []
          image_urls.each do |image_url|                    
            color_info[:images] << image_url.gsub(/\?.*/, "?sh=800")
          end
          
          color_infos << color_info
        end
        swatch_tags.each_with_index do |swatch_tag, swatch_tags_index|
          if swatch_tag.parent['class'].include?('selected')            
            next
          end
          color_info = {}          
          b.goto swatch_tag['href']
          product_doc = Nokogiri::HTML(b.html)          
          sizes_tags = product_doc.xpath('//ul[contains(@class, "swatches size")]/li/a') 
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            next if size_tag.parent['class'].include?('unselectable')
            next if size_tag.parent['class'].include?('size-chart-link')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = swatch_tag['href']

          color_id = color_info[:color].split(' ').join('_').downcase

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@id="thumbnails"]//li[contains(@class, "thumb")]//img/@src').map(&:text)          
          
          color_info[:image_url] = swatch_tag['style'].match(/background: url\((.*?)\)/)[1] rescue nil

          unless color_info[:image_url]
            color_info[:image_url] = image_urls[0]
          end
          
          
          color_info[:images] = []
          image_urls.each do |image_url|                    
            color_info[:images] << image_url.gsub(/\?.*/, "?sh=800")
          end
                   
          color_infos << color_info
        end
      rescue Exception => e
        puts '^' * 20
        puts "Encounted error #{e} while scraping secondary images on WetSeal scraper"
        puts '^' * 20
      end
      
      all_sizes = []
      color_infos.each do |color_info|
        all_sizes << color_info[:sizes]
      end

      close_browser(b)
      item = { colors: color_infos, description: desc, size: all_sizes.flatten.compact.uniq, more_info: more_info }      
      item = item.merge({msrp: msrp}) if msrp

      return item
    end

  end
end