class Anthropologie < StoreAPI
  class << self
    def store_items(items_sold=nil, more_info=nil)
      @store = Store.where(name: "Anthropologie").last
      @categories = @store.categories.where.not(url: nil).external.non_sale + @store.categories.where.not(url: nil).external.sale
      created_at = DateTime.now
      @categories.each do |category|
        puts "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          begin
            main_doc = Nokogiri::HTML(open(category.url))
          rescue Exception => e
            puts "^" * 40
            puts "Exception at main doc anthropologie for category: #{category.url}"
            puts "error: #{e}"
            puts "^" * 40
          end
          if main_doc.present?
            items_per_page = 100
            total_page_count = main_doc.css(".pages .page-number")[1].present? ? main_doc.css(".pages .page-number")[1].text.to_i : 1.to_i
            @items = []
            (0..(total_page_count-1)).each_with_index do |page_no, i|
              start_count = items_per_page * i
              store_page_no_url = category.url
              store_page_no_url = store_page_no_url + "&itemCount=100&indexStart=#{start_count + 1}"
              puts "#" * 50
              puts "Curent Page: #{i} / #{total_page_count}"
              puts "Page Value: #{start_count}"
              puts "$" * 20
              @items << fetch_anthropologie_page_data(Nokogiri::HTML(open(store_page_no_url)))
              if items_sold
                make_items_and_sizes_sold(@items.flatten, @store, category)
              elsif more_info && @store.items.count > 0 && category.items.count > 0
                update_more_info_for_items(@items.flatten, @store, category)
              else
                create_items(@items.flatten, @store, category, created_at)
             end
            end
          end
        end
      end

      complete_item_creation(@store)
    end

    def get_prices(item)
      if item.at_css(".item-description .item-price .price.PriceAlertText").present?
        price_text = item.at_css(".item-description .item-price .price.PriceAlertText").text
        was_price = item.at_css(".item-description .item-price .price.PriceAlertText .wasPrice") || item.at_css(".item-description .item-price .price.PriceAlertText .was-price")
        msrp_text = was_price.present? ? was_price.text : ""
      else
        price_text = item.at_css(".item-description .item-price .price").text
        msrp_text = ""
      end
      price_text.slice!(msrp_text)
      price = price_text
      msrp = msrp_text.present? ? msrp_text.match(/\$([0-9]+[\.]*[0-9]*)/)[0] : ""
      {price: price, msrp: msrp}
    end

    def color_and_more_info(product, item_url, item_import_key)
      colors_info = []
      puts ""
      puts "$$$$$$$$$ Color and More Info $$$$$$$$$$"
      if product["moreInfo"].present?
        puts "Description : #{product['more']}"
        description = Nokogiri::HTML(product["moreInfo"]).css("body").children.children.text.strip
      else
        description = product["description"]
      end
      more_info_data = Nokogiri::HTML(product["longDescription"])
      more_info = more_info_data.present? ? more_info_data.css("ul li").map {|i| i.text.strip } : []
      all_sizes = []
      product["colors"].each do |color|
        base_url = "http://images.anthropologie.com/is/image/Anthropologie/"
        item_images = color["viewCode"].map {|c| base_url + "#{color['id']}_#{c}?wid=425" }
        size_ids = color["sizes"].map {|s| s["id"] }.compact.uniq.flatten
        all_sizes << color["sizes"].map {|i| i["displayName"]}
        color_name = color["displayName"].present? ? color["displayName"].downcase.split(" ").join("_") : nil
        colors_info << {color: color["displayName"],
         sizes: product["skusInfo"].map {|i| i["size"] if size_ids.include?(i["sizeId"]) }.compact.uniq.flatten,
         images: item_images,
         color_item_url: item_url,
         import_key: "#{item_import_key}_#{color_name}"
        }
      end
      puts "------------- Color and More Info ENDS -------------"
      {colors_info: colors_info, size: all_sizes.compact.uniq.flatten, description: description, more_info: more_info}
    end

    def fetch_anthropologie_page_data(page_doc)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      page_doc.css(".category-items .prod.category-item").each do |item|
        image_url = item.at_css(".imageWrapper.item-image img.lazy")["data-original"]
        source_url = "http://www.anthropologie.com"
        url = source_url + item.at_css(".imageWrapper.item-image a")["href"]
        import_key = "anthropologie_#{item.at_css(".imageWrapper.item-image")["id"].gsub(/[^\d]/, '')}"
        product_code = item.at_css(".item-quickshop a")["data-quickshop-id"]
        api_url = "http://www.anthropologie.com/api/v1/product/" + product_code
        item_json_data = JSON.parse(Curl.get(api_url).body)
        color_and_more_info = color_and_more_info(item_json_data["product"], url, import_key)
        name = item.at_css(".item-description a").text
        price_values = get_prices(item)
        item_hash = {name: name, url: url, price: price_values[:price], msrp: price_values[:msrp], image_url: image_url, import_key: import_key}
        item_hash = item_hash.merge(color_and_more_info) if color_and_more_info[:description].present?
        item_hash = item_hash.merge(colors: color_and_more_info[:colors_info]) if color_and_more_info[:colors_info].present?
        data << item_hash
      end
      data
    end
    
    def has_more_info
      true
    end
  end
end