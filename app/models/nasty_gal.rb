class NastyGal < StoreAPI
  class << self
    def store_items
      @store = Store.find_by(name: "Nasty Gal")
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category| 
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"       
          @items = fetch_ng_data(Nokogiri::HTML(open("#{category.url}?view=All", 'User-Agent' => 'DoteBot')))
          @items.flatten!
          create_items(@items, @store, category, created_at)
        end
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      if item.at_css('.original-price').try(:text).present? && item.at_css('.current-price.sale').try(:text).present?
        msrp = item.css('.original-price').try(:text).try(:strip)
        price = item.css('.current-price.sale').try(:text).try(:strip)
      else
        msrp = ""
        price = item.css('.current-price').try(:text).try(:strip)
      end
      { msrp: msrp, price: price}
    end

    def image_url_for(item)
      "http:#{item.at_css('.category-item-thumb').attr('src').gsub("browse-l", "zoom")}"
    end

    def url_for(item)
      item.at_css('.product-link').attr('href')
    end

    def name_for(item)
      product_name = item.at_css('.product-name')
      product_name.nil? ? nil : product_name.text
    end

    def fetch_ng_data(page_doc)
      data = []
      page_doc = page_doc.dup
      page_doc.css('script[type="text/template"]').each do |script_item|
        items = Nokogiri::HTML(script_item.text)
        items.css('.product-list-item').each do |item|
          name = name_for(item)
          if name.nil?
            puts "^" * 40
            puts "ERROR: Could not parse item name for item: #{item}"
            puts "^" * 40
            next
          end
          image_url = image_url_for(item)
          import_key = "nasty_gal_#{item.attr('data-product-id')}"
          url = url_for(item)
          more_info_dict = get_more_infos(url, import_key, image_url)
          data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item)).merge(more_info_dict)
        end        
      end

      data
    end
    
    def has_more_info
      true
    end

    def get_more_infos(product_url, item_import_key, item_image_url)
      b = Watir::Browser.new(:phantomjs)   
      b.goto product_url
      product_doc = Nokogiri::HTML(b.html)
      
      desc = product_doc.xpath('//div[@class="product-description"]/p[position()=1]').text
      more_info = product_doc.xpath('//div[@class="product-description"]/p[position()=2]').text.split("*")

      color_infos = []
      color_info = {}

      begin
        color_info[:image_url] = item_image_url
        if sizes_tags = product_doc.xpath('//div[@class="product-sizes"]/div[contains(@class, "radio")]/label[@class="sku-label"]')
          color_info[:sizes] = sizes_tags.map(&:text)
        else
          color_info[:sizes] = ['One Size']
        end
        color_info[:color] = 'One Color'
        color_info[:color_item_url] = product_url        
        if image_tags = product_doc.xpath('//ul[@id="product-images-carousel"]/li[@class="carousel-item"]/img/@src')
          color_info[:images] = image_tags.map(&:text)
        else
          color_info[:images] = []
        end
        color_info[:import_key] = "#{item_import_key}_one_color"
        color_info[:images] = color_info[:images].map{ |image_url| image_url.include?('http') ? image_url.gsub('detail', 'zoom') : "http:#{image_url.gsub('detail', 'zoom')}" }
        color_infos << color_info
      rescue Exception => e
        puts '^' * 40
        puts "Encounted error #{e} while scraping secondary images on NastyGal scraper"
        puts '-' * 40
      end
      b.close if b

      return { colors: color_infos, description: desc, size: color_info[:sizes], more_info: more_info }
    end


  end
end