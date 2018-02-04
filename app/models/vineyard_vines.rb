class VineyardVines < StoreAPI
  DOMAIN = ""
  ITEM_REGEX = Regexp.new('document\.write\(\\"(.*?)\\"\)', true)
  IMAGE_REGEX = /http:\/\/.*(\?.*)/i
  class << self
    def store_items
      @store = Store.where(name: "Vineyard Vines").last
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category| 
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"       
          begin
            main_doc = Nokogiri::HTML(open(category.url, "User-Agent" => "DoteBot"))
          rescue Exception => e
            Sidekiq.logger.info "^" * 40
            Sidekiq.logger.info "Error At Opening Category URL: #{category.url}"
            Sidekiq.logger.info "Error: #{e}"
            Sidekiq.logger.info "^" * 40
          end
          if main_doc.present?
            all_url = main_doc.try(:at_css, "a.nextpreviewall").try(:attr, "href")
            main_doc = Nokogiri::HTML(open(all_url, "User-Agent" => "DoteBot")) if all_url.present?
            @items = []
            store_page_no_url = category.url
            begin
              @items << fetch_vinyard_vines_data(main_doc, category.name)
              @items = @items.flatten
            rescue Exception => e
              Sidekiq.logger.info "^" * 40
              Sidekiq.logger.info "Error At Items Fetching for URL: #{store_page_no_url}"
              Sidekiq.logger.info "Error: #{e}"
              Sidekiq.logger.info "^" * 40
            end
            create_items(@items, @store, category, created_at)
          end
        end        
      end
      complete_item_creation(@store)
    end

    def get_prices(item)
      price = item.css(".pricing .price .salesprice").text.gsub(/\n+|\r+|\t+|\s+/, "")
      price = item.css(".pricing .price").text.gsub(/\n+|\r+|\t+|\s+/, "") if price.blank?
      msrp = item.css(".pricing .price .standardprice").try(:text).try(:gsub, /\n+|\r+|\t+|\s+/, "") || ""
      {price: price, msrp: msrp}
    end

    def get_image_url(nokogiri_img_obj)
      uri = URI.parse(nokogiri_img_obj.attr("src"))
      "#{uri.scheme}://#{uri.host}#{uri.path}"
    end

    def fetch_vinyard_vines_data(page_doc, category_name=nil)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      page_doc.css(".producthits .productresultarea .productlisting .product.producttile").each do |item|
        nokogiri_item = Nokogiri::XML item.at_css(".thumbnail script").text.gsub(/\n+|\r+/, "\n").squeeze("\n").match(ITEM_REGEX)[1]
        item_anchor = nokogiri_item.at_css(".productimage a")
        url = item_anchor.attr("href")        
        image_url = get_image_url(nokogiri_item.at_css(".orignalimage"))
        name = item.at_css(".name").text.gsub(/\n+|\r+|\t/, "")
        import_key = "vineyard_vine_#{item.at_css("a")["href"].split("_")[1]}"
        price_values = get_prices(item)
        color_infos = get_more_infos(url, import_key)        
        data << {name: name, url: url, price: price_values[:price], msrp: price_values[:msrp], image_url: image_url, import_key: import_key}.merge(color_infos)      
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

        desc = product_doc.xpath('//div[@id="pdescription"]/p[@class="small"]').text.strip      
        more_info = product_doc.xpath('//div[@id="details"]').try(:children).try(:map, &:text)
        if more_info.present? && !desc.present?
          more_info.each do |info|
            desc = "#{desc}\n#{info.strip}"
          end
          more_info = []
        end
        color_info = {}
        swatch_tags = product_doc.xpath('//div[@class="swatches color"]/ul[contains(@class, "swatchesdisplay")]/li/a')      
        # DO scrapping unselelected colors
        swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|          
          next unless swatch_tag.parent['class'].include?('selected')
          
          color_info = {}

          sizes_tags = product_doc.xpath('//div[@class="swatches size"]/ul[@class="swatchesdisplay"]/li/a')       
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            next if size_tag.parent['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag.text.strip
          color_info[:color_item_url] = product_url

          color_id = color_info[:color].downcase.split(' ').join('_')

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@class="productthumbnails"]/img/@src').map(&:text)          
          
          unless image_urls.present?
          end

          color_info[:image_url] = remove_quotes_for_image_url(swatch_tag.parent['style'].match(/background: url\((.*?)\)/)[1]) rescue nil          

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
          next if swatch_tag.parent['class'].include?('selected') 
          color_info = {}

          b.execute_script("$('div.productthumbnails').html('');")
          
          b.a(text: swatch_tag.text).click
          b.element(:xpath => "//div[@class='productthumbnails']/img").wait_until_present
          product_doc = Nokogiri::HTML(b.html)

          sizes_tags = product_doc.xpath('//div[@class="swatches size"]/ul[@class="swatchesdisplay"]/li/a')       
          color_info[:sizes] = []
          
          sizes_tags.each do |size_tag|
            next if size_tag.parent['class'].include?('unselectable')
            color_info[:sizes] << size_tag.text.strip
          end
          unless sizes_tags.present?
            color_info[:sizes] << "One Size"
          end

          color_info[:color] = swatch_tag.text.strip
          color_info[:color_item_url] = product_url

          color_id = color_info[:color].downcase.split(' ').join('_')

          color_info[:import_key] = "#{item_import_key}_#{color_id}"

          image_urls = product_doc.xpath('//div[@class="productthumbnails"]/img/@src').map(&:text)          
          
          color_info[:image_url] = remove_quotes_for_image_url(swatch_tag.parent['style'].match(/background: url\((.*?)\)/)[1]) rescue nil          

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
        puts '^' * 40
        puts "Encounted error while scraping VineyardVines item: #{product_url}"
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
    
    def remove_quotes_for_image_url(image_url)
      if image_url[0] == '"' || image_url[0] == "'"
        image_url[0] = ''        
      end
      if image_url[-1] == '"' || image_url[-1] == "'"
        image_url[-1] = ''        
      end
      image_url
    end

  end
end