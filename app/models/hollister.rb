class Hollister < StoreAPI
  IMAGE_REGEX = /(.*?\?)(.*)/i
  DOMAIN = "http://www.hollisterco.com"
  class << self
    def store_items(items_sold=nil)
      @store = Store.where(name: "Hollister").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        Sidekiq.logger.info "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          begin
            main_doc = Nokogiri::HTML(open(category.url, "User-Agent" => "DoteBot"))
          rescue Exception => e
            Sidekiq.logger.info "^" * 40
            Sidekiq.logger.info "Error At Opening Category URL: #{category.url}"
            Sidekiq.logger.info "Error: #{e}"
            Sidekiq.logger.info "^" * 40
          end
          if main_doc.present?
            @items = []
            store_page_no_url = category.url
            Sidekiq.logger.info "#" * 50
            begin
              @items << fetch_hollister_data(main_doc, category, !items_sold)
              if items_sold
               make_items_sold(@items.flatten, @store, category)
             else
                @items.flatten!
                create_items(@items, @store, category, created_at)
              end
            rescue Exception => e
              Sidekiq.logger.info "^" * 40
              Sidekiq.logger.info "Error: #{e}"
              Sidekiq.logger.info "Error At Items Fetching for URL: #{store_page_no_url}"
              Sidekiq.logger.info "Message:\n #{e.message}"
              Sidekiq.logger.info "backtrace:\n #{e.backtrace.join('\n')}"
              Sidekiq.logger.info "^" * 40
              Airbrake.notify_or_ignore(
                e,
                parameters: {},
                cgi_data: ENV.to_hash
              )
            end
          end
        end
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      price_item = item.at_css('.grid-product__price')
      price = price_item.at_css('.grid-product__price--low').text.strip rescue nil
      return {} if price.blank?
      msrp = price_item.at_css('.grid-product__price--high').try(:text).try(:strip) || ""
      {price: price, msrp: msrp}
    end

    def build_images_for base_url, hollister_item_id = "01"
      ["http:#{base_url.gsub('01', hollister_item_id)}prod1", "http:#{base_url.gsub('01', hollister_item_id)}model1", "http:#{base_url.gsub('01', hollister_item_id)}model2"]
    end

    def image_url_for(item)
      image_thumb_url = item.at_css('.grid-product__image-wrap > .grid-product__image-link > .grid-product__image').attr("data-src")
      image_thumb_url.gsub(IMAGE_REGEX, 'http:\1$productMagnify-r-hol$')
    end

    def get_colors_and_more_info_data(url, category)
      item_doc = Nokogiri::HTML(open(url, "User-Agent" => "DoteBot"))
      description_tag = item_doc.at_css(".product__details p")
      description = description_tag.children.to_a.first.text
      more_info = description_tag.children.to_a.fourth.text.split(" / ") if description_tag.children.count > 3
      @colors, @sizes = [], []
      base_url = url.gsub("?ofp=true","").split("_").first
      images_base_url = item_doc.at_css(".product__images ul li img").attr("src").gsub("?$productMain-r-hol$", "").gsub("prod1", "").gsub("model1", "")

      @sizes = get_sizes url, category

      item_doc.css(".product-sizes__size-wrapper.color").each do |color|
        if color.attr("data-valid-short-skus").present?
          color_div = color.css("div")
          color_name = color.attr("data-defining-attribute-value")
          item_id = color.css("div").attr("data-seq")
          import_key = "hollister_#{color_div.attr('data-productid')}_#{item_id}"
          item_url = base_url + "_#{item_id}"

          color_valid_skus = color.attr("data-valid-short-skus").split(",")
          sizes = get_sizes color_valid_skus, item_url, category

          images = build_images_for(images_base_url, item_id)
          @colors << {color: color_name, color_item_url: item_url, images: images, sizes: sizes, import_key: import_key}
        end
      end
      data = {colors_info: @colors, size: @sizes, description: description, more_info: more_info}
      unless @colors.present?
        secondary_images = build_images_for(images_base_url)
        data.merge!({secondary_images: secondary_images})
      end
      data
    end

    def get_sizes color_skus = [], url, category
      item_doc = Nokogiri::HTML(open(url, "User-Agent" => "DoteBot"))
      @color_sizes = []
      if category.name == "Jeans" || category.name == "Bras"

        length_ul_name, waist_ul_name = "Length", "Waist" if category.name == "Jeans"
        length_ul_name, waist_ul_name = "Cup", "Band" if category.name == "Bras"

        length_ul_tag = item_doc.css(".product-sizes__container ul").select {|ul| ul.attr("data-defining-attribute-name") == length_ul_name }
        waist_ul_tag = item_doc.css(".product-sizes__container ul").select {|ul| ul.attr("data-defining-attribute-name") == waist_ul_name }
        if waist_ul_tag.present? && length_ul_tag.present?
          waist_ul_tag.first.css("li").each do |waist_li|
            waist_valid_skus = waist_li.attr("data-valid-short-skus").split(",")
            waist_valid_skus = waist_valid_skus & color_skus if color_skus.present?
            length_ul_tag.first.css("li").each do |length_li|
              length_valid_skus = length_li.attr("data-valid-short-skus").split(",")
              if (length_valid_skus & waist_valid_skus).size > 0
                @color_sizes << "#{waist_li.css("div").text} #{length_li.css("div").text}"
              end
            end
          end
        end
      else
        size_ul_tag = item_doc.css(".product-sizes__container ul").select {|ul| ul.attr("data-defining-attribute-name") == "Size" }
        size_ul_tag.first.css("li").each do |size_li|
          size_valid_skus = size_li.attr("data-valid-short-skus").split(",")
          size_valid_skus = size_valid_skus & color_skus if color_skus.present?
          @color_sizes << size_li.css("div").text if size_valid_skus.present?
        end if size_ul_tag.present?
      end

      if @color_sizes.count == 0
        item_doc.css(".product-sizes__size").each do |size|
          @color_sizes << size.text if size.parent.attr("data-valid-short-skus").present?
        end
      end
      @color_sizes
    end

    def fetch_hollister_data(page_doc, category, should_fetch_more_info)
      data = []
      @image_urls = []
      page_doc.css('.grid > .grid-product').each do |item|
        prices = prices_for(item)
        next if prices.blank?
        name = item.at_css('.grid-product__name').text.strip
        import_key = "hollister_#{item.at_css('.grid-product__name').attr("data-productid")}"
        image_url = image_url_for(item)
        url = "#{DOMAIN}#{item.at_css('.grid-product__image-wrap > .grid-product__image-link').attr('href')}"
        item_hash = {}
        if should_fetch_more_info
          colors_and_more_info_data = get_colors_and_more_info_data(url, category)
          mf_data = colors_and_more_info_data
          item_hash = { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item))
          item_hash = item_hash.merge({description: mf_data[:description], more_info: mf_data[:more_info], size: mf_data[:size]}) if mf_data[:description].present?
          item_hash = item_hash.merge({secondary_images: mf_data[:secondary_images]}) if mf_data[:secondary_images].present?
          item_hash = item_hash.merge(colors: colors_and_more_info_data[:colors_info]) if colors_and_more_info_data[:colors_info].present?
        else
          item_hash = { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item))
        end
        data << item_hash
      end
      data
    end
    
    def has_more_info
      true
    end
  end
end