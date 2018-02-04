class CharlotteRusse < StoreAPI
  REGEX_FOR_URL = /.*\/(\d+)\/(\d+)\.uts$/i
  URL = "http://www.charlotterusse.com/catalog/thumbnail_body_frag.jsp?parentCategoryId=%%parent category%%&subCategoryId=%%child category%%&mode=viewall"
  SINGLE_CAT_URL = "http://www.charlotterusse.com/catalog/thumbnail_body_frag.jsp?subCategoryId=%%child category%%&mode=viewall"
  class << self
    def store_items(items_sold=false)
      @store = Store.where(name: "Charlotte Russe").last      
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        Sidekiq.logger.info "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          url = if category.url =~ REGEX_FOR_URL
            matches = category.url.match REGEX_FOR_URL
            URL.gsub("%%parent category%%", matches[1]).gsub("%%child category%%", matches[2])
          elsif category.url.match /.*\/(\d+)\.uts$/i
            matches = category.url.match /.*\/(\d+)\.uts$/i
            SINGLE_CAT_URL.gsub("%%child category%%", matches[1])
          end || ""
          next if url.blank?

          main_doc = Nokogiri::HTML(open(url, 'User-Agent' => 'DoteBot'))    
          if main_doc.present?
            @items = fetch_cr_data(main_doc, !items_sold)
            if items_sold
              make_items_sold_given_items(@items.flatten, @store, category)
            else
              create_items(@items, @store, category, created_at)
            end
          end
        end
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      begin
        msrp = if item.at_css('.common-msrp-price').text.strip.present?
          item.at_css('.common-msrp-price').text.strip
        else
          if item.at_css('.prodPromoMsg').text.strip.present?
            msrp_t = item.at_css('.catalog-display-price-text').text.strip
            msrp_t = item.at_css('.common-msrp-price').text.strip if msrp_t.blank?
            msrp_t = "$#{msrp_t}" unless msrp_t =~ /\$\d+/
            msrp_t
          end
        end || ""
        price = if item.at_css('.salePrice').try(:text).try(:strip).present? || item.at_css('.catalog-display-price-text').try(:text).try(:strip).present?
          price_t = item.at_css('.salePrice').text.strip
          price_t = item.at_css('.catalog-display-price-text').text.strip if price_t.blank?
          price_t
        else
          promo_msg = item.at_css('.prodPromoMsg > p:first').try(:text).try(:strip).try(:downcase)
          if promo_msg =~ /now:\s\$\d+/i
            price_t = promo_msg.downcase.split("now:")[1].strip
          elsif promo_msg =~ /take\s(\d+)\%\soff/i
            off_percent = promo_msg.match(/take\s(\d+)\%\soff/i)[1].to_i
            price_t = "$#{price_from_off_percent(msrp.split("$")[1].to_f, off_percent)}"
          elsif promo_msg =~ /(\d+)\sfor\s\$(\d+)/i
            price_t = msrp
            msrp = ""
          end
          price_t
        end
      rescue Exception => e
        {}
      end
      {msrp: msrp, price: price}
    end

    def image_url_for(item)
      "https:#{item.at_css('#imageHolderURL > img').attr('src').gsub("hei=280&wid=200", "hei=1080")}"
    end

    def url_for(item)
      "http://www.charlotterusse.com#{item.css('.prodTitle > h4 > a').attr('href')}"
    end

    def name_for(item)
      item.css('.prodTitle > h4 > a').text.strip
    end
    
    ######################################################
    # Get Colors, Sizes, Description, MorInformation     #
    ######################################################
    def get_more_infos(item_url)
      @colors = []
      @sizes = []
      description = ''
      more_info = []
      begin
        b = Watir::Browser.new(:phantomjs)
        b.goto item_url
        item_doc = Nokogiri::HTML(b.html)
        
        description = item_doc.css('span[itemprop=description]').try(:text).chomp.gsub(/\t/, '').gsub(/\n/, '').gsub(/\r/, '')

        swatch_colors = []
        item_doc.css('#swatchWrapper li.swatch').each do |swatch|
          swatch_colors << swatch.attr('dropval')
        end

        import_key = item_doc.css('input[name=productId]').attr('value')

        swatch_colors.each_with_index do |swatch_color, color_index|  
          b.element(:css => "li[dropval=\"#{swatch_color}\"]").when_present.click
          item_doc = Nokogiri::HTML(b.html)
          image_url = item_doc.css("li[dropval=\"#{swatch_color}\"]").attr('fullimg').text
          @sizes = []
          
          item_doc.css('.sizing select option').each do |option|
            @sizes << option.attr('value') unless option.attr('value').empty?
          end

          images = []
          item_doc.css('.altImagesContainer img').each do |img|              
            images << 'https:' + img.attr('src').gsub("?hei=90&qlt=85,1&wid=75&fmt=jpeg&resMode=bicub&op_sharpen=1", "?$s7product$&&id=WSdrq1&fmt=jpg&amp;fit=constrain,1&wid=445&amp;hei=576")
          end

          color = {
            image_url: image_url,
            color: swatch_color,
            sizes: @sizes,
            color_item_url: item_url,
            import_key: "#{import_key}_#{swatch_color}",
            images: images
          }
          @colors << color
        end
        close_browser(b)
      rescue Exception => e
        puts "^" * 40
        puts "An error occured in get_more_infos: #{e}"     
        puts "^" * 40
        close_browser(b)
      end
      {colors: @colors, size: @sizes, description: description, more_info: more_info}
    end

    def fetch_cr_data(page_doc, should_scrape_more_info)
      data = []
      page_doc.css(".item").each do |item|
        name = name_for(item)
        import_key = "charlotte_russe_#{item.attr('id')}"
        image_url = image_url_for(item)
        url = url_for(item)        
        
        if should_scrape_more_info
          more_infos = get_more_infos(url)
          data << { name: name, import_key: import_key, image_url: image_url, url: url}.merge(prices_for(item)).merge(more_infos)
        else
          data << { name: name, import_key: import_key, image_url: image_url, url: url}.merge(prices_for(item))
        end
      end
      data
    end

    def has_more_info
      true
    end
  end
end