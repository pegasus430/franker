require 'ruby-prof'
class Lululemon < StoreAPI
  class << self

    def store_items(items_sold=false)
      @store = Store.where(name: "lululemon").last
      @categories = @store.categories.where.not(url: nil).external
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          puts "Category URL : #{category.url}"
          time = Benchmark.measure do
            begin
              @items = fetch_lululemon_page_data(Nokogiri::HTML(open(category.url)))
              if items_sold
                make_items_and_sizes_sold(@items.flatten, @store, category)
              else
                create_items(@items, @store, category, created_at)
              end
            rescue Exception => e
              puts "^" * 40
              puts "Error At Items Fetching for URL: #{category.url}"
              puts "Error: #{e}"
              puts "^" * 40
            end
          end
        end
      end

      complete_item_creation(@store)
    end

    def get_more_info_for_an_item(url)
      begin
        item_info_doc = Nokogiri::HTML(open(url))
        desc_tag = item_info_doc.at_css(".why-we-made-this")
        more_info_tag = item_info_doc.at_css(".product.content ul")
        description = desc_tag.present? ? item_info_doc.at_css(".why-we-made-this").children.text.strip : nil
        if more_info_tag.present?
          more_info = item_info_doc.at_css(".product.content ul").children.map do |i|
            i.text.strip.force_encoding('ASCII-8BIT').encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => ''}) if i.text.strip.length > 0
          end.compact.reject(&:empty?)
        else
          more_info = nil
        end
        size_info = item_info_doc.css("ul#sizes li a")
        size = size_info.count > 1 ? size_info.map {|i| i["title"].strip } : [size_info[0]["title"].strip]
        {description: description, more_info: more_info, size: size.reject(&:empty?)}
      rescue Exception => e
          puts "*"*10 + "Error At Opening ITEM info URL" + "*"*10
        puts "Error: #{e}"
        3.times {puts "Error"}
        puts "URL: #{url}"
        puts "*"*10 + "Error" + "*"*10
      end
    end

    def get_color_data(item, url)
      colors_info = []
      item.css(".switchThumb").each do |color|
        color_url = generate_urls(url, color["cc"], color["sku"])
        color_data = get_individual_color_data(color_url)
        color_key = color.at_css("img")["src"].scan(/\d{4,5}/).first
        import_key = "lululemon_#{item["id"].gsub(/[^\d]/, '')}_#{color_key}"
        colors_info << { image_url: color.at_css("img")["src"],
          color_item_url: color_url,
          sizes: color_data[:sizes],
          images: color_data[:images],
          import_key: import_key}
      end
      colors_info
    end

    def get_individual_color_data(color_url)
      color_page_info = Nokogiri::HTML(open(color_url))
      images = color_page_info.css("#productImage #productImageContainer a").flat_map do |image|
        image["rev"]
      end.compact

      sizes = color_page_info.css("ul#sizes li a").flat_map do |size|
        size["title"].strip unless size["class"].include?("soldOut")
      end.compact
      {images: images, sizes: sizes}
    end

    def generate_urls(main_url, cc, sku)
      uri = URI.parse(main_url)
      parsed_params = CGI::parse(uri.query)
      parsed_params["cc"] = [cc]
      parsed_params["skuId"] = [sku]
      uri.query = URI.encode_www_form(parsed_params)
      uri.to_param
    end

    def fetch_lululemon_page_data(page_doc)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      page_doc.css(".productList .productRow .product").each do |item|
        if item.at_css("ul.product-images").present?
          image_url = item.at_css("ul.product-images li.current img")["src"].gsub("$cdp_thumb$", "$pdp_main$")
          source_url = "http://shop.lululemon.com"
          url = source_url + item.at_css("ul.product-images li.current a")["href"].gsub(' ', '%20')
          colors_and_size_info = get_color_data(item, url)
          item_more_info = get_more_info_for_an_item(url)
          puts "Image !!!!!!!!!!"
          puts "Image URL : #{image_url}"
          puts "!!! Image Ends !!!"
          3.times { puts " " }
          name = item.at_css("h3 a .OneLinkNoTx").text
          if item.at_css("span.amount").present?
            price = item.at_css("span.amount").text.split("\n").join("")
          else
            price = item.at_css("p").text.split("-")[0]
          end
          # binding.pry
          msrp = item.at_css("i span.amount").present? ? item.at_css("i span.amount").text.split("\n").join("") : 0
          import_key = "lululemon_#{item["id"].gsub(/[^\d]/, '')}"
          item_hash = {name: name, url: url, price: price, msrp: msrp, image_url: image_url, import_key: import_key}
          item_hash = item_hash.merge(item_more_info) if item_more_info[:description].present?
          item_hash = item_hash.merge({colors: colors_and_size_info}) if colors_and_size_info.present?
          puts "!!!! Item Data !!!!!"
          puts item_hash
          puts "!!!! Item Data Ends !!!!!"
          puts "@" * 20
          data << item_hash
        end
      end
      data
    end
    
    def has_more_info
      true
    end
  end
end