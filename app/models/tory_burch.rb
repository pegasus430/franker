class ToryBurch < StoreAPI
  class << self
    def store_items
      @store = Store.find_by(name: "Tory Burch")
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category|        
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"
          @items = fetch_tb_data(Nokogiri::HTML(open(category.url.try(:strip), 'User-Agent' => 'DoteBot')), category)          
          @items.flatten!
          create_items(@items, @store, category, created_at)
        end        
      end
      complete_item_creation(@store)
    end

    def prices_for(item)
      if item.at_css(".discountprice").present?
        msrp = item.at_css(".standardprice").text.strip
        price = item.at_css(".salesprice").text.strip
      else
        msrp = ""
        price = item.at_css(".salesprice").text.strip
      end
      { msrp: msrp, price: price}
    end

    def image_url_for(item)
      item.at_css('.product-image-primary').attr("src").strip.gsub("$trb_grid_224x254$", "$trb_fullscreen$&fmt=jpeg")
    end

    def secondary_image_url_for(item)
      item.at_css('.alternateimage').attr("src").strip.gsub("$trb_grid_224x254$", "$trb_fullscreen$&fmt=jpeg")
    end

    def url_for(item)
      item.at_css(".name").at_css('a').attr("href")
    end

    def name_for(item)
      item.at_css(".name").at_css('a').text.strip
    end

    def fetch_tb_data(page_doc, category)      
      data = []
      products = page_doc.css('.productlisting .product .producttitle-inner').present? ? page_doc.css('.productlisting .product .producttitle-inner') : page_doc.css('.productlisting .product .producttile-inner')
      products.each do |item|        
        name = name_for(item)
        image_url = category.name == "Denim" ? image_url_for(item) : secondary_image_url_for(item)
        url = url_for(item)       
        import_key = "tory_burch_#{url.gsub(/.*\/(.*)?.html\?.*/i, '\1')}"
        more_info_dict = get_more_infos(url, import_key)
        data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item)).merge(more_info_dict)
      end
      data
    end

    def get_more_infos(product_url, item_import_key) 
      desc = ''
      more_info = []
      color_infos = []
      
      begin
        b = Watir::Browser.new(:phantomjs)      
        b.goto product_url
        product_doc = Nokogiri::HTML(b.html)
      
        product_sku = get_product_sku(product_url)
        desc = product_doc.xpath('//div[@itemprop="description"]//div[@class="panelContent"]').text.gsub("Color: ", "").strip
        more_info = product_doc.xpath('//div[contains(@class, "detailsPanel")]/div[@class="panelContent"]/ul/li').try(:map, &:text)

        color_info = {}
        swatch_tags = product_doc.xpath('//ul[@id="swatchesselect"]/li/a')      
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|          
          color_info = {}
          b.goto swatch_tag['name']
          product_doc = Nokogiri::HTML(b.html)
        
          sizes_tags = product_doc.xpath('//div[contains(@class, "variantdropdown")]//select/option')       
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            next unless size_tag.attr('value').present?
            next if size_tag.text.include?('not available')
            color_info[:sizes] << size_tag.attr('value')
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag['title']
          color_info[:color_item_url] = swatch_tag['name']

          color_id = swatch_tag.parent['data-value']

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = get_image_urls(product_doc, product_sku, color_id)          
          color_info[:images] = image_urls
          if swatch_tag.xpath('.//img').present?
            color_info[:image_url] = swatch_tag.xpath('.//img/@src').text
          else
            color_info[:image_url] = image_urls[0]
          end
                            
          color_infos << color_info
        end        
      rescue Exception => e
        puts '^' * 40
        puts "Encounted error while scraping item information with url: #{product_url}"
        puts "Error: #{e}"
        puts '^' * 40
      end
      
      all_sizes = []
      color_infos.each do |color_info|
        all_sizes << color_info[:sizes]
      end

      close_browser(b)
      return { colors: color_infos, description: desc, size: all_sizes.flatten.compact.uniq, more_info: more_info }
    end
    
    def has_more_info
      true
    end

    ### Remove edge quotes
    def get_url_removed_quotes(image_url)
      if image_url[0] == '"' || image_url[0] = "'"
        image_url[0] = ''        
      end
      if image_url[-1] == '"' || image_url[-1] = "'"
        image_url[-1] = ''        
      end
      image_url
    end

    ### Get product sku from product url
    def get_product_sku(product_url)
      product_url.split('/')[-1].match(/(.*)\.html/)[1]
    end

    ### Get image urls
    def get_image_urls(product_doc, product_sku, color_id)
      suffixes = get_suffixes(product_doc, product_sku, color_id)
      image_urls = []
      suffixes.each do |suffix|
        image_urls << "http://s7d5.scene7.com/is/image/ToryBurchLLC/TB_#{product_sku}_#{color_id}_#{suffix}?hei=800"
      end      
      image_urls
    end

    ### Get suffixes for all additional images
    def get_suffixes(product_doc, product_sku, color_id)
      json_path = product_doc.xpath('//script[contains(@src, "imageSet=")]/@src')
      unless json_path.present?
        json_path = product_doc.xpath('//script[contains(@src, "req=set,json,UTF-8")]/@src')
      end

      json_path = CGI::unescapeHTML(json_path.text)
      # phantomjs doesn't support video, need to delete video related params
      if json_path.include?(';video;')
        json_path = json_path.gsub(/,ToryBurchLLC.*;video;/, '')
      end

      json_response = Nokogiri::HTML(open(URI.encode(json_path)))      
      suffixes = json_response.text.scan(/TB_#{product_sku}_#{color_id}_([A-Z])"/)      
      suffixes.flatten.compact.uniq
    end

  end
end