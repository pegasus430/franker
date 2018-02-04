class Zara < StoreAPI
  class << self
    def store_items
      @store = Store.where(name: "Zara").last
      @categories = @store.categories.where.not(url: nil).external
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          puts "Category URL : #{category.url}"
          begin
            main_doc = Nokogiri::HTML(open(category.url, "User-Agent" => "DoteBot"))
          rescue Exception => e
            puts "^" * 40
            puts "Error: #{e}"
            puts "Error At Opening Category URL: #{category.url}"
            puts "^" * 40
          end
          if main_doc.present?
            items = []
            store_page_no_url = category.url
            puts "#" * 50
            begin
              items << fetch_zara_page_data(main_doc)
              items = items.flatten
            rescue Exception => e
              puts "^" * 40
              puts "Error: #{e.message}"
              puts "Error At Items Fetching for URL: #{store_page_no_url}"
              puts "^" * 40
            end

            create_items(items, @store, category, created_at)
          end
        end
      end
      
      complete_item_creation(@store)
    end

    def get_prices(item)
      if item.at_css(".product-info .price span").present?
        if item.at_css(".product-info .price span.sale").present?
          price = item.at_css(".product-info .price span.sale")["data-ecirp"]
          msrp = item.at_css(".product-info .price span.crossOut")["data-ecirp"]
        else
          price = item.at_css(".product-info .price span")["data-ecirp"]
          msrp = ""
        end
        {price: price, msrp: msrp}
      else
        nil
      end
    end

    def get_more_info_for_an_item(item_info_doc)
      begin
        desc_tag = item_info_doc.at_css("p.description").text.strip
        more_info_tag = item_info_doc.css(".section.zonasPrenda p")
        description = desc_tag.present? ? desc_tag : nil
        if more_info_tag.present?
          more_info = item_info_doc.css(".section.zonasPrenda p").map do |i|
            i.text.strip
          end.compact.reject(&:empty?)
        else
          more_info = nil
        end
        return {description: description, more_info: more_info}
      rescue Exception => e
        puts "^" * 40
        puts "Error: #{e}"
        puts "Error At Opening ITEM info URL: #{url}"
        puts "^" * 40
      end
    end

    def get_color_data(item, item_info_doc, base_import_key)
      colors_info = []
      data = get_individual_color_data(item, item_info_doc)
      item_info_doc.css("form div label").each do |color_information|
        color_code = color_information.attr("data-colorcode")
        color_size_data = nil
        if data.present? && data["colors"].present?
          data["colors"].each do |color|
            data_color_code = color["code"]
            if data_color_code == color_code
              color_size_data = color
              break
            end
          end
        end

        color_name = color_information.css("div").attr("title").value
        image_url = "http:" + color_information.css("div img").attr("src").value
        images = generate_images(color_size_data)
        sizes = color_size_data.present? ? color_size_data["sizes"].flat_map {|s| s["description"] if s["availability"] == "InStock" }.compact : nil
        colors_info << { image_url: image_url,
          color_item_url: item.at_css("a.item.gaProductDetailsLink")["href"],
          sizes: sizes,
          images: images,
          color: color_name,
          import_key: "#{base_import_key}_#{color_code}"}
      end
      {colors_info: colors_info}
    end

    def generate_images(color)
      urls = color["pColorImgNames"].map do |img_name|
        first = color["colorImgUrl"].split("/w")[0]
        timestamp = color["colorImgUrl"].split("/w")[1].split("?")[1]
        img_url = first + "w/1024/#{img_name}_1.jpg?" + timestamp
        url = img_url.gsub("2w", "2/w")
        url
      end
      return urls
    end

    def get_individual_color_data(item, item_info_doc)
      data = item_info_doc.to_s
      data.gsub!(/[\t\r\n]/i, "")
      regex = /.*<script\stype="text\/javascript">.*?zara\.core\.startModule\('ItxProductDetailSelectionModule',\s({.*})?}\);}\);<\/script><\/section>.*/i
      begin
        matched_data = data.match(regex)[1]
      rescue Exception => e
        puts "^" * 40
        puts "Error At Item color data Fetching for Item URL: #{item.at_css("a.item.gaProductDetailsLink")["href"]}"
        puts "Item Info : #{item_info_doc}"
        puts "Error: #{e.message}"
        puts "Data : #{data}"
        puts "regex : #{regex}"
        puts "URL: #{store_page_no_url}"
        puts "^" * 40
      end
      regex1 = /.*?,productData:\s({.*}),sizeSelectTplId:\s.*/i
      parsed_data = JSON.parse(matched_data.match(regex1)[1])
      parsed_data
    end

    def generate_urls(main_url, cc, sku)
      uri = URI.parse(main_url)
      parsed_params = CGI::parse(uri.query)
      parsed_params["cc"] = [cc]
      parsed_params["skuId"] = [sku]
      uri.query = URI.encode_www_form(parsed_params)
      uri.to_param
    end

    def fetch_zara_page_data(page_doc)
      data = []
      name, url, price, msrp, image_url, import_key = ""

      page_doc.css("#products .product.grid-element").each_with_index do |item, i|
        Librato.timing 'zara.item.time' do
        url = item.at_css("a.item.gaProductDetailsLink")["href"]
        item_info_doc = Nokogiri::HTML(open(url, "User-Agent" => "DoteBot"))
        
        colors_and_size_info = {}
        all_sizes = []
        item_more_info = {}
        import_key = "zara_#{item.at_css('a.item.gaProductDetailsLink img').attr('data-ref')}"
        if item_info_doc.css("#product").present?
          Librato.timing 'zara.item_color.time' do
          colors_and_size_info = get_color_data(item, item_info_doc, import_key)
          all_sizes = item_info_doc.css("#product .size-select .product-size").map {|s| s.at_css(".size-name").text.strip }
          item_more_info = get_more_info_for_an_item(item_info_doc)
          end
        end
        image_url = "http:" + "#{item.at_css("a.item.gaProductDetailsLink img")["data-src"].gsub('w/400', 'w/560')}"
        name = item.at_css(".product-info .name.item").text
        if name.present? && get_prices(item).present?
          price_values = get_prices(item)
          item_hash = {name: name, url: url, price: price_values[:price], msrp: price_values[:msrp], image_url: image_url, import_key: import_key}
          item_hash = item_hash.merge(item_more_info.merge(size: all_sizes)) if item_more_info[:description].present?
          item_hash = item_hash.merge({colors: colors_and_size_info[:colors_info]}) if colors_and_size_info[:colors_info].present?
          data << item_hash
        end
        end
      end
      data
    end
    
    def create_image(url)
      begin
        tf = MiniMagick::Image.read(open(url, "User-Agent" => "DoteBot").read)
        @image = Image.new(file: tf)
      rescue Exception => e
        puts "^" * 40
        puts "Exception Occurred for MiniMagick Image"
        puts "URL : #{url}"
        puts "Image Details : #{@image.inspect}"
        puts "Error: #{e}"
        puts "^" * 40
        unless @image.nil?
          @image.destroy
          @image = nil
        end
      end

      unless @image.nil?
        begin
          @image.save
          Curl.get(@image.file.url)
        rescue Exception => e
          puts "^" * 40
          puts "Exception Occurred for Image Creation - create_zara_image"
          puts "Item Details : #{item}"
          puts "Image Details : #{@image.inspect}"
          puts "Error: #{e}"
          puts "^" * 40
          unless @image.nil?
            @image.destroy
            @image = nil
          end
        end
      end
      @image
    end
    
    def create_multiple_images(urls, imageable_id, type)
      if urls.present? && urls.count > 0
        urls.each do |url|
          begin
            tf = MiniMagick::Image.read(open(url, "User-Agent" => "DoteBot").read)
            @image = Image.new(file: tf, imageable_type: type, imageable_id: imageable_id)
          rescue Exception => e
            puts "^" * 40
            puts "Exception Occurred for MiniMagick Multiple Images"
            puts "Item Url : #{url} imageable_id: #{imageable_id} type: #{type}"
            puts "Image Details : #{@image.inspect}"
            puts "Error: #{e}"
            puts "^" * 40
            unless @image.nil?
              @image.destroy
              @image = nil
            end
          end

          unless @image.nil?
            begin
              @image.save
              Curl.get(@image.file.url)
            rescue Exception => e
              puts "^" * 40
              puts "Exception Occurred for Image Creation - create_zara_multiple_images"
              puts "Item Url : #{url} imageable_id: #{imageable_id} type: #{type}"
              puts "Image Details : #{@image.inspect}"
              puts "Error: #{e}"
              puts "^" * 40
              unless @image.nil?
                @image.destroy
                @image = nil
              end
            end
          end
        end
      end
    end
    
    def has_more_info
      true
    end
    
  end
end
