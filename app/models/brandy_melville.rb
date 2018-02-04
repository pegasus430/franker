class BrandyMelville < StoreAPI
  class << self
    def store_items(items_sold=false)
      @store = Store.where(name: "Brandy Melville").last
      @categories = @store.categories.where.not(url: nil).external.non_sale + @store.categories.where.not(url: nil).external.sale
      created_at = DateTime.now
      @categories.each do |category|
        puts "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          begin
            main_doc = Nokogiri::HTML(open(category.url))
          rescue Exception => e
            puts "^" * 40
            puts "Error At Opening Category URL: #{category.url}"
            puts "Error: #{e}"
            puts "^" * 40
          end
          if main_doc.present?
            total_page_count = (main_doc.css(".pager ul li a").count - 1).to_i
            total_page_count = total_page_count > 1 ? total_page_count : 1
            @items = []
            (1..total_page_count).each_with_index do |page_no, i|
              store_page_no_url = category.url
              store_page_no_url = store_page_no_url + "?p=#{page_no}"
              puts "#" * 50
              puts "Curent Page: #{i} / #{total_page_count}"
              begin
                @items << fetch_brandy_melville_page_data(Nokogiri::HTML(open(store_page_no_url)), !items_sold)
              rescue Exception => e
                puts "^" * 40
                puts "Error At Items Fetching for URL: #{store_page_no_url}"
                puts "Error: #{e}"
                puts "^" * 40
              end
            end
            
            if items_sold
              make_items_sold_given_items(@items.flatten, @store, category)
            else
              create_items(@items.flatten, @store, category, created_at)
            end
          end
        end
      end
      
      complete_item_creation(@store)
    end

    def get_prices(item)
      price = item.at_css(".price-box .regular-price").text
      msrp = ""
      {price: price, msrp: msrp}
    end

    def fetch_brandy_melville_page_data(page_doc, should_fetch_more_info=true)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      page_doc.css(".category-products li.item").each do |item|
        url = item.at_css("a.product-link-image")["href"]
        image_medium = item.at_css(".product-image")["src"]
        image_large = item.at_css(".product-image")["src"].sub("small_image/230x345", "image/357x535")
        image_url = image_large.present? ? image_large : image_medium
        name = item.at_css(".product-name a").text
        import_key = "brandymelville_#{item.at_css("a.product-link-image")["id"].gsub(/[^\d\.]/, '')}"
        price_values = get_prices(item)
        
        item_more_info = {}
        secondary_images = []
        colors = []
        if should_fetch_more_info
          begin
            item_info_doc = Nokogiri::HTML(open(url))
            item_more_info = get_more_info_for_an_item(item_info_doc)
            secondary_images = item.css(".product-image.secondary-image").map {|i| i["rel"].sub("image/230x345", "image/357x535") if i.present? }
            colors = [color_and_more_info(import_key, url, secondary_images, item_more_info[:size], item_more_info[:more_info])]
          rescue Exception => e
            puts "^" * 40
            puts "Error getting more info for url: #{url}"
            puts "Error: #{e}"
            puts "^" * 40
          end
        end
        if item_more_info[:description].present?
          data << {name: name, url: url,
                   price: price_values[:price], msrp: price_values[:msrp],
                   image_url: image_url, import_key: import_key, colors: colors}.merge(item_more_info)
        else
          data << {name: name, url: url,
                   price: price_values[:price], msrp: price_values[:msrp],
                   image_url: image_url, import_key: import_key}
        end
      end
      data
    end
    
    def get_more_info_for_an_item(item_info_doc)
      description = item_info_doc.at_css(".description-container .std").text.strip
      more_info = item_info_doc.at_css("ul#product-attribute-specs-table").children.map {|i| i.text.strip if i.text.strip.length > 0 }.compact
      size_info = item_info_doc.css(".product-options .product-option")
      size = size_info.count > 1 ? size_info.map {|i| i.text } : [size_info.text]
      {description: description, more_info: more_info.reject(&:empty?), size: size.reject(&:empty?)}
    end
    
    def color_and_more_info(item_import_key, item_url, images, sizes, more_info)
      color_name = "One Color"
      more_info.each do |info|
        if info.include? "Color:"
          color_name = info.gsub("Color: ", '')
        end
      end
      {color: color_name,
       sizes: sizes,
       images: images,
       color_item_url: item_url,
       import_key: item_import_key
      }
    end
    
    def has_more_info
      true
    end
  end
end