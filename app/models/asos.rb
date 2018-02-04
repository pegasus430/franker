class ASOS < StoreAPI

  ADVERTISER_ID = "35719"

  class << self    
    
    def store_items
      @store = Store.find_by(name: "ASOS")
      @categories = @store.categories.external
      created_at = DateTime.now
      b = Watir::Browser.new(:phantomjs)

      @categories.each do |category|
        next if category.url.nil? || category.url == "NA" || category.url.empty?
        Sidekiq.logger.info "Category URL : #{category.url}"
          
        b.goto category.url  
        cat_doc = Nokogiri::HTML(b.html)
        @cur_page = 1
        @total_page = get_total_page(cat_doc)
        @import_keys = []

        while @cur_page <= @total_page do
          begin        
            if @cur_page > 1
              navigate_to_page(b, @cur_page)
              cat_doc = Nokogiri::HTML(b.html)
            end

            @item_urls = get_item_urls_for(cat_doc)          
            @item_urls.each do |item_url|
              @items = []
              @items << get_item_detail(item_url)            
            
              next if @items[0].nil?           
              create_items(@items, @store, category, created_at, false)            
              @import_keys << @items.flat_map {|i| i[:new_import_key].present? ? i[:new_import_key] : i[:import_key] }.compact
            end
          rescue Exception => e
            puts "^" * 40
            puts "ERORR: failed to scrape page #{@cur_page} for category url: #{category.url}"
            puts "Error: #{e}"
            puts "^" * 40
          end
          @cur_page = @cur_page + 1
        end
        make_items_sold(@import_keys, @store, category)
      end
      complete_item_creation(@store)
      close_browser(b)
    end

    def prices_for(item)
      if item.at_css('#ctl00_ContentMainPage_ctlSeparateProduct_lblProductPrice')        
        price = item.at_css('#ctl00_ContentMainPage_ctlSeparateProduct_lblProductPrice').text.strip
        msrp = price
      else
        price = 0
        msrp = 0
      end
      if item.at_css('#ctl00_ContentMainPage_ctlSeparateProduct_lblRRP')
        price = item.at_css('#ctl00_ContentMainPage_ctlSeparateProduct_lblRRP').text.gsub('RRP', '').strip
      end
      
      {msrp: msrp, price: price}
    end

    def has_more_info
      true
    end

    def get_total_page(cat_doc)
      begin
        total_page = cat_doc.xpath('//ol[@class="page-nos"]/li[position()=last()-1]/a/text()').try(:text).to_i
      rescue
        total_page = 1
      end
      total_page
    end
    
    def navigate_to_page(browser, cur_page)
      browser.execute_script('$("ul#items").remove();')
      browser.a(text: cur_page.to_s).click
      browser.driver.manage.timeouts.implicit_wait = 10
      browser.ul(id: 'items').wait_until_present 
    end

    def get_item_urls_for(cat_doc)
      urls = cat_doc.xpath('//ul[@id="items"]/li/a[@class="desc"]/@href').map(&:value)
    end

    def get_color_infos(b, item_doc, item_url, item_import_key)
      all_sizes = []
      color_infos = []
      color_names = []
      item_doc.xpath('//select[@id="ctl00_ContentMainPage_ctlSeparateProduct_drpdwnColour"]/option[position()>1]/@value').each do |node|
        unless node.text == '-1'
          color_names << node.text
        end
      end

      color_names.each_with_index do |color_name, index|
        color_item_doc = item_doc
        if index > 0
          b.execute_script("$('#ctl00_ContentMainPage_pnlThumbImages ul.productThumbnails').remove();")
          b.select_list(:id => 'ctl00_MainContent_ddlColor').option(:value => color_name).select
          b.ul(id: 'productThumbnails').wait_until_present 
          color_item_doc = item_doc
        end
        images = []

        color_image_url = color_item_doc.xpath('//img[@id="ctl00_ContentMainPage_imgMainImage"]/@src').text
        color_item_doc.xpath('//div[@id="ctl00_ContentMainPage_pnlThumbImages"]/ul[@class="productThumbnails"]/li/a/img/@src').each_with_index do |img_tag, index|
          
          if index == 0
            color_image_url = img_tag.text             
          end
          images << img_tag.text.gsub("s.jpg", "xxl.jpg")
        end
        
        color_sizes = []
        color_item_doc.xpath('//select[@id="ctl00_ContentMainPage_ctlSeparateProduct_drpdwnSize"]/option').each do |node|
          unless node.attr('value') == '-1'
            unless node.text.downcase.include?('not available')
              color_sizes << node.text.strip
            end
          end
        end
        if color_sizes.empty?
          color_sizes << "One Size"          
        end
        
        all_sizes << color_sizes

        color_code = color_name.downcase
        color_infos << { image_url: color_image_url,
                             sizes: color_sizes,
                             color: color_name,
                             color_item_url: item_url,
                             images: images,
                             import_key: "#{item_import_key}_#{color_code}" }
      end
      
      return { colors: color_infos, size: all_sizes.flatten.compact.uniq }

    end

    def get_item_detail(item_url)
      begin
        unless item_url.include?('http:')
          item_url = "http://www.asos.com#{item_url}"
        end
        
        b = Watir::Browser.new(:phantomjs)   
        b.goto item_url
        item_doc = Nokogiri::HTML(b.html)
        
        name = item_doc.at_css('#ctl00_ContentMainPage_ctlSeparateProduct_lblProductTitle').text
        desc = item_doc.at_css("#ctl00_ContentMainPage_productInfoPanel a").try(:children).try(:map, &:text).join(' - ')
        more_info = item_doc.at_css("#ctl00_ContentMainPage_productInfoPanel ul").try(:children).try(:map, &:text)

        sku = item_doc.at_css('#ctl00_ContentMainPage_ctlSeparateProduct_hdnSku').attr('value').strip
        import_key = "asos_#{sku}"
        image_url = item_doc.xpath('//meta[@name="og:image"]/@content').text
        
        prices = prices_for(item_doc)      
        color_infos = get_color_infos(b, item_doc, item_url, import_key)
        
        close_browser(b)

        return {
          name: name,         
          import_key: import_key, 
          image_url: image_url,        
          url: item_url, 
          description: desc,
          more_info: more_info, 
          size: color_infos[:size], 
          colors: color_infos[:colors]
        }.merge(prices)
      rescue
        close_browser(b)
        return nil
      end

    end
  end

end