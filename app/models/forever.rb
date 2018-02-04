class Forever < StoreAPI

  ADVERTISER_ID = 37768

  class << self

    def store_items
      @store = Store.find_by(name: "Forever 21")
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Forever 21 Category URL : #{category.url}"
          @cur_page = 1
          @total_page = 1
          @items = []
          @import_keys = []
          begin
            begin
              @page_data = Nokogiri::HTML(open(category.url.try(:strip) + "&pagesize=30&page=#{@cur_page}", 'User-Agent' => 'DoteBot'))
            rescue Exception => e
              puts "^" * 40
              puts "Error At Opening Category URL: #{category.url}"
              puts "Error: #{e}"
              puts "^" * 40
              break
            end  

            begin
              @total_page = @page_data.xpath('//ul[@class="pagenumber"][position()=last()]/li[@class="PagerOtherPageCells"][position()=last()-1]/a').first.text.strip.to_i
            rescue Exception => e
              puts "^" * 40
              puts "Error At calculating total page : #{e}"
              puts "^" * 40
              @total_page = 1
            end
            @error = false
            if @total_page > 400
              @error = true
            end

            @items = fetch_items(category, @cur_page, @store)
            @items.flatten!
            create_items(@items, @store, category, created_at, false)
            @import_keys << @items.flat_map {|i| i[:new_import_key].present? ? i[:new_import_key] : i[:import_key] }.compact
            @import_keys.flatten!

            @cur_page = @cur_page + 1            
          end while (@cur_page) <= @total_page && !@error
          
          make_items_sold(@import_keys, @store, category)
        end
      end
      complete_item_creation(@store)
    end
    
    #############################
    ######### More Info #########
    #############################
    def prices_for(item)
      if item.at_css('.oprice')
        o_price = item.at_css(".oprice").try(:text)
        n_price = item.at_css("font.price font").try(:text)
        price = o_price.gsub("Was:", "")
        msrp = n_price.gsub("Now:", "")
      else
        price = item.at_css(".price").try(:text)
        msrp = price
      end
      
      {msrp: msrp, price: price}
    end

    def image_url_for(item)      
      item.at_css('.ItemImage img').attr("src").gsub("default_330", "default_750")
    end

    def image_url_for_sold(item)      
      item.at_css('.ItemImageOOS .pdpLink img').attr("src").gsub("default_330", "default_750")
    end

    def url_for(item)
      item.at_css(".ItemImage a.pdpLink").attr("href")
    end
    
    def url_for_sold(item)
      item.at_css(".ItemImageOOS a.pdpLink").attr('href')
    end

    def name_for(item)
      item.at_css(".DisplayName").text.strip
    end

    def fetch_items(category, page, store)
      url = category.url.try(:strip) + "&pagesize=30&page=#{page}"
      b = Watir::Browser.new(:phantomjs)
      
      b.goto url
      item_doc = Nokogiri::HTML(b.html)
      close_browser(b)

      data = []
      products = item_doc.xpath('//table[@id="ctl00_MainContent_dlCategoryList"]/tbody/tr/td')
      products.each do |item|
        begin
          name = name_for(item)
          if item.at_css('.ItemImageOOS')
            image_url = image_url_for_sold(item)
            url = url_for_sold(item)
          else  
            url = url_for(item)
            image_url = image_url_for(item)
          end
          import_key = get_import_key(image_url)
          import_key = "#{store.name.split(' ').join('').downcase}_#{import_key}"

          more_info_dict = get_more_info(import_key, url)
          
          prices = prices_for(item)
          data << { name: name, import_key: import_key, image_url: image_url, url: url, description: more_info_dict[:description], more_info: more_info_dict[:more_info], size: more_info_dict[:size], colors:more_info_dict[:color_infos] }.merge(prices)
        rescue  
        end
      end    
      
      data
    end  

    #############################
    ######### More Info #########
    #############################
    def has_more_info
      true
    end
    
    def get_more_info(item_import_key, item_url)
      color_infos, all_sizes = [], []
      description = nil
      
      item_doc = Nokogiri::HTML(open(item_url))
       
      description = item_doc.at_css("#product_overview p").try(:text).strip        
      more_info = item_doc.at_css("#product_overview ul").try(:children).try(:map, &:text)
      color_hash = item_doc.xpath('//table[@id="ctl00_MainContent_dlColorChart"]/tbody/tr/td/input[@type="image"]')
      
      color_list = []
      item_doc.xpath('//div[@id="ctl00_MainContent_upColorList"]/select/option').each do |node|       
        next if node.try(:text).downcase == 'color'
        color_list << node.try(:text)          
      end
          
      color_swatches_urls = item_doc.css("#ctl00_MainContent_dlColorChart td input").collect { |input_tag| input_tag.attr("src") }.compact
      color_ids = item_doc.css("#ctl00_MainContent_upColorList select option").collect { |option| option.attr("value").split("|").last if option.attr("value").length > 0 }.compact
      
      b = Watir::Browser.new(:phantomjs)
      b.goto item_url
      
      color_swatches_urls.each_with_index do |color_sw_url, index|
        color_id = color_ids[index]
        image_url = color_sw_url
        color_name = color_list[index]

        color_url = item_url.gsub("VariantID=", "VariantID=#{color_id}")
        import_key = "#{item_import_key}_#{color_id}"
        
        item_color_doc = Nokogiri::HTML(open(color_url))
        b.goto color_url
        size_doc = Nokogiri::HTML(b.html)
        images = build_color_images(size_doc)
        
        sizes = item_color_doc.css("#ctl00_MainContent_ddlSize option").select { |option| option.text != "Size" && option.text.index("Sold out").nil? }.try(:map, &:text)
        all_sizes << sizes
        color_code = color_name.split(" ").join('_').downcase
        
        color_infos << {image_url: image_url,
                        sizes: sizes,
                        color: color_name,
                        color_item_url: color_url,
                        images: images,
                        import_key: "#{item_import_key}_#{color_code}"}
      end
      
      close_browser(b)
      return { description: description, size: all_sizes.flatten.compact.uniq, color_infos: color_infos, more_info: more_info }
    end

    def build_color_images(color_item_doc)      
      color_item_doc.xpath('//td[@class="imgbutton"]//li/a/img/@src').map{ |img_src| img_src.try(:text).gsub("_58", "_750")}        
    end

    def get_import_key(default_image_url)      
      default_image_url.split('/')[-1].split("?")[0].split(".")[0].split("-")[0]
    end

  end
end