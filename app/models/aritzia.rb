class Aritzia < StoreAPI
  class << self
    def store_items
      @store = Store.where(name: "Aritzia").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        puts "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          main_doc = Nokogiri::HTML(open(category.url))
          items_per_page = 20.to_f
          begin
            total_items_count = main_doc.at_css("#pagebar-total-value").text.to_f
          rescue Exception => e
            puts "^" * 40
            puts "Exception at total items aritzia"
            puts "error: #{e}"
            puts "^" * 40
          end
          if total_items_count.present?
            total_page_count = (total_items_count / items_per_page).ceil
            start_number = 0
            @items = []
            (1..total_page_count).each_with_index do |page_no, i|
              start_number = i > 0 ? (start_number + 20) : start_number
              store_page_no_url = category.url
              store_page_no_url = store_page_no_url + "?start=#{start_number}"
              puts "#" * 50
              puts "Curent Page: #{i} / #{total_page_count}"
              puts "Page Value: #{start_number}"
              begin
                @items << fetch_aritzia_page_data(Nokogiri::HTML(open(store_page_no_url)))
                @items = @items.flatten
              rescue Exception => e
                puts "^" * 40
                puts "Error At Items Fetching for URL: #{store_page_no_url}"
                puts "Error: #{e}"
                puts "^" * 40
              end
              puts "$" * 20
              create_items(@items, @store, category, created_at)
            end
          end
        end
      end
      
      complete_item_creation(@store)
    end

    def get_prices(item)
      if item.at_css(".product-pricing .product-standard-price span").present?
        price = item.at_css(".product-pricing .product-sales-price span").text
        msrp = item.at_css(".product-pricing .product-standard-price span").text
      else
        price = item.at_css(".product-pricing .product-sales-price span").text
        msrp = ""
      end
      {price: price, msrp: msrp}
    end

    def fetch_aritzia_page_data(page_doc)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      # binding.pry
      page_doc.css(".search-result-items .product-tile").each do |item|
        url = item.at_css(".product-image  a")["href"].gsub(' ', '%20')
        image_medium = item.at_css(".product-image img")["data-original"]
        image_large = item.at_css(".product-image img")["data-original"]
        image_url = image_medium.present? ? image_medium : image_large
        puts "Image URL : #{image_url}"
        name = item.at_css(".product-name a").text
        import_key = "artizia_#{item['data-itemid']}"
        price_values = get_prices(item)
        data << {name: name, url: url, price: price_values[:price], msrp: price_values[:msrp], image_url: image_url, import_key: import_key}
      end
      data
    end
  end
end