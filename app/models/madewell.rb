class Madewell < StoreAPI
  class << self
    def store_items
      @store  = Store.where(name: "Madewell").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        puts "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          main_doc = Nokogiri::HTML(open(category.url))
          items_per_page = 90
          @items = []
          if main_doc.at_css("td.topNavTxtSale a span").present?
            total_items_count = main_doc.at_css("td.topNavTxtSale a span").text.match(/\d+(?:\.\d+)?/)[0].to_f
            total_page_count = (total_items_count / items_per_page).ceil

            (0..(total_page_count-1)).each_with_index do |page_no, i|
              store_page_no_url = category.url

              puts "Curent Page: #{i}/#{total_page_count}"
              @items << fetch_madewell_page_data(Nokogiri::HTML(open(store_page_no_url)))
              begin
                @items = @items.flatten
                create_items(@items, @store, category, created_at)
              rescue Exception => e
                puts "^" * 40
                puts "Error: #{e}"
                puts "Error At Items Fetching for URL: #{store_page_no_url}"
                puts "^" * 40
              end
            end
          else
            store_page_no_url = category.url
            begin
              @items << fetch_madewell_page_data(Nokogiri::HTML(open(store_page_no_url)))
              @items = @items.flatten
              create_items(@items, @store, category, created_at)
            rescue Exception => e
              puts "^" * 40
              puts "Error: #{e}"
              puts "Error At Items Fetching for URL: #{store_page_no_url}"
              puts "^" * 40
            end
          end
        end
      end

      complete_item_creation(@store)
    end

    def get_colors_sizes_json_data(item)
      price, sale_price = 0,0
      url = item.at_css(".get-quickshop")["data-producturl"]
      base_url = url.split("?")[0]
      prod_code = item.at_css("button").attr("data-productcode")
      url1 = "https://www.madewell.com/browse2/ajax/product_details_ajax.jsp?prodCode=#{prod_code}"
      json_data = Curl.get(url1).body
      info = Nokogiri::HTML(json_data)
      if info.at_css(".sws-message .sold-out").present? && info.at_css(".sws-message .sold-out").text.present?
        return {error: "sold_out"}
      else
        images_hash = get_images_hash(json_data)
        json_data.gsub!(/\n*/i, "")
        new_regex = /<script>.*?productDetailsJSON\s=\s'(.*)?';var\simgSelectedColor.*<\/script>/i
        complete_data = JSON.parse(json_data.match(new_regex)[1])
        {colors_info: complete_data, images_info: images_hash}
      end
    end

    # Copied from jcrew.rb
    def get_images_hash(json_data)
      info = Nokogiri::HTML(json_data)
      color_images = {}
      item_images = {}
      info.css(".color-box a").each do |image|
        color_images[image["id"]] = image.at_css("img")["src"]
        item_images[image["id"]] = image.at_css("img")["data-imgurl"]
      end
      {color_images: color_images, item_images: item_images}
    end

    def get_more_info_for_an_item(url)
      begin
        item_info_doc = Nokogiri::HTML(open(url))
        desc_tag = item_info_doc.at_css("#prodDtlBody").text
        more_info_tag = item_info_doc.at_css("#prodDtlBody ul")
        description = desc_tag.present? ? desc_tag.gsub(/\t/, '').gsub(/\n/, '').gsub(/\r/, '') : nil
        if more_info_tag.present?
          more_info = more_info_tag.children.map do |i|
            i.text.strip.force_encoding('ASCII-8BIT').encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => ''}).gsub(/\t/, '').gsub(/\n/, '').gsub(/\r/, '') if i.text.strip.length > 0
          end.compact.reject(&:empty?)
        else
          more_info = nil
        end
        secondary_images = []
        item_info_doc.css("#product0 .product-detail-thumbnails .float-left img").each_with_index do |item, i|
          secondary_images << item["data-imgurl"].gsub("pdp_fs418", "pdp_enlarge")
        end
        {description: description, more_info: more_info, secondary_images: secondary_images}
      rescue Exception => e
        puts "^" * 40
        puts "Error: #{e}"
        puts "Error At Opening item URL: #{url}"
        puts "^" * 40
      end
    end

    def get_color_data(data, url, secondary_images, item_import_key)
      colors_info = []
      item_base_url = url.split("?").first
      all_sizes = data[:colors_info]["sizeset"].map {|c| c["size"] }
      data[:colors_info]["colorset"].each do |color_data|

        color_name = color_data["colordisplayname"].split(" ").join("-")
        color_item_url = item_base_url + "?color_name=#{color_name}"

        colors_info << {image_url: data[:images_info][:color_images][color_data["color"]],
        images: [data[:images_info][:item_images][color_data["color"]].try(:gsub!, "$pdp_fs418$", "$pdp_enlarge$")] + secondary_images,
        color: color_data["colordisplayname"],
        sizes: color_data["sizes"].map {|s| s["sizelabel"] },
        color_item_url: color_item_url,
        import_key: "#{item_import_key}_#{color_data["color"]}"}
      end
      {colors_info: colors_info, all_sizes: all_sizes}
    end

    def fetch_madewell_page_data(page_doc)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      page_doc.css("table td.arrayProdCell").each do |item|
        if item.at_css("td.arrayImg a").present? && item.at_css("img").present?
          url = URI::encode(item.at_css("td.arrayImg a")["href"].gsub(' ', '%20'))
          sc_data = get_colors_sizes_json_data item
          sold_out = sc_data[:error] if sc_data[:error].present?
          unless sold_out.present?
            image_url = item.at_css("img")["src"].split("?")[0] + ("?$pdp_fs418$")
            name = item.at_css("img")["alt"]
            import_key = "madewell_#{item.at_css(".get-quickshop")["data-productcode"]}"

            item_more_info = get_more_info_for_an_item(url)
            secondary_images = item_more_info[:secondary_images]
            colors_and_size_info = get_color_data(sc_data, url, secondary_images, import_key)

            price_values = get_common_prices item

            item_hash = {name: name, url: url, price: price_values[:price], msrp: price_values[:msrp], image_url: image_url, import_key: import_key}
            item_hash = item_hash.merge(item_more_info.merge(size: colors_and_size_info[:all_sizes])) if item_more_info[:description].present?
            item_hash = item_hash.merge({colors: colors_and_size_info[:colors_info]}) if colors_and_size_info[:colors_info].present?

            data << item_hash
          end
        end
      end
      data
    end

    def has_more_info
      true
    end
  end
end