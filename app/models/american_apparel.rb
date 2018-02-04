include ActionView::Helpers::SanitizeHelper

class AmericanApparel < StoreAPI
  AMERICAN_APPAREL_DOMAIN = "http://store.americanapparel.net"
  class << self
    def store_items(items_sold=false)
      @store = Store.where(name: "American Apparel").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        puts "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          begin
            main_doc = Nokogiri::HTML(open(category.url, "User-Agent" => "DoteBot"))
          rescue Exception => e
            puts "^" * 40
            puts "Error: #{e}"
            puts "Error At Opening Category URL: #{category.url}"
            puts "^" * 40
          end
          if main_doc.present?
            @items = []
            @final_items = []
            begin
              @items << fetch_am_apparel_page_data(main_doc)
              @items = @items.flatten
            rescue Exception => e
              puts "^" * 40
              puts "Error: #{e}"
              puts "Error At Items Fetching for url: #{category.url}"
              puts "^" * 40
            end
            
            unless items_sold
              begin
                @final_items << fetch_color_and_more_info(@items)
                @final_items = @final_items.flatten
              rescue Exception => e
                puts "^" * 40
                puts "Error: #{e}"
                puts "Error At Items Fetching for url: #{category.url}"
                puts "^" * 40
              end
            end

            if items_sold
              make_items_sold_given_items(@items, @store, category)
            else
              create_items(@final_items, @store, category, created_at)
            end
          end
        end
      end

      complete_item_creation(@store)
    end

    def get_prices(item)
      prices = item.at_css(".pricing")
      if prices.at_css(".normal").present?
        price = prices.at_css(".normal").text.gsub(/\r\n|\n|\r/, "").gsub(/(\D*\$)(\D*)/, "")
        msrp = ""
      else
        prices = item.at_css(".pricing")
        msrp = prices.at_css(".priceSaleListing").text.gsub(/\r\n|\n|\r/, "").gsub(/(\D*\$)(\D*)/, "")
        price = prices.at_css(".salePrice").text.gsub(/\r\n|\n|\r/, "").gsub(/(\D*\$)(\D*)/, "")
      end
      {price: price, msrp: msrp}
    end

    def fetch_am_apparel_page_data(page_doc)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      page_doc.css(".productGroup .product").each do |item|
        url = "#{AmericanApparel::AMERICAN_APPAREL_DOMAIN}#{item.at_css("a")["href"]}"
        image_url = item.at_css("a img")["src"].gsub("$ProductThumbnail$", "$ProductZoomImage$")
        name = item.at_css(".name a").text
        import_key = "american_apparel_#{item.at_css("a")["href"].split("_")[1]}"
        import_key = import_key.split(';jsessionid')
        import_key = import_key[0]

        price_values = get_prices(item)
        data << {name: name, url: url, price: price_values[:price], msrp: price_values[:msrp], image_url: image_url, import_key: import_key}
      end
      data
    end

    # This function returns the colors, sizes, images and description of an item
    def fetch_color_and_more_info(items)
      fdata = []
      additional_images = []
      name, url, price, msrp, image_url, import_key, description = ""
      items.each do |item|
        name = item[:name]
        url = item[:url]
        price = item[:price]
        msrp = item[:msrp]
        image_url = item[:image_url]
        import_key = item[:import_key]

        begin
          doc = Nokogiri::HTML(open(url, "User-Agent" => "DoteBot"))
        rescue Exception => e
          puts "^" * 40
          puts "Error: #{e}"
          puts "Error At Opening Product URL: #{url}"
          puts "^" * 40
        end

        swatches = Hash.new
        swatch_url_flags = Hash.new
        doc.css(".colors ul li .swatch").each do |swatch|
          swatch_url = swatch.attr("style")[/\(.*?\)/]
          swatch_title = swatch.attr("title")
          if swatch_url.present?
            swatches[swatch_title] = swatch_url[1..-2]
            swatch_url_flags[swatch_title] = 'URL'
          else
            swatches[swatch_title] = swatch.attr("style")[/background-color:#.*?;/][18..-2]
            swatch_url_flags[swatch_title] = 'RGB'
          end
        end

        coder = HTMLEntities.new
        color_size_data = doc.at('input[@id="skuVarData"]')['value']
        color_size_data = coder.decode(color_size_data)
        color_size_data = JSON.parse(color_size_data)

        description = get_item_description(doc)
        additional_images = get_additional_images(color_size_data['productId'])
        sizes = get_item_sizes(color_size_data)
        colors = get_item_colors(color_size_data, import_key, url, swatches, swatch_url_flags, additional_images)
        fdata << {name: name, url: url, price: price, msrp: msrp, image_url: image_url, import_key: import_key, description: description, size: sizes, colors: colors}
      end
      fdata
    end

    def get_item_colors(sdata, item_import_key, item_url, swatches, swatch_url_flags, additional_images)
      colors_info = []

      sdata['color2size'].each_with_index do |cs, index|
        if swatch_url_flags[cs[0]] == 'RGB'
          colors_info << {color: cs[0],
                          sizes: cs[1],
                          rgb: swatches[cs[0]],
                          images: [sdata['colors'][cs[0]]['zoomImage']].concat(additional_images),
                          color_item_url: item_url,
                          import_key: "#{item_import_key}_#{cs[0].gsub(' ', '')}"
          }
        else
          colors_info << {color: cs[0],
                          sizes: cs[1],
                          image_url: swatches[cs[0]],
                          images: [sdata['colors'][cs[0]]['zoomImage']].concat(additional_images),
                          color_item_url: item_url,
                          import_key: "#{item_import_key}_#{cs[0].gsub(' ', '')}"
          }
        end
      end
      colors_info
    end

    def get_item_sizes(sdata)
      all_sizes = []

      sdata['sizes'].each do |s|
        all_sizes.push(s['value'])
      end
      all_sizes
    end

    def get_item_description(doc)
      description = doc.css(".longDesc-container .longDesc-container tr td").text.strip
      description = strip_tags(description)
      description
    end

    def get_additional_images(id)
      all_images = []

      url = "http://i.americanapparel.net/services/ATG/Image.ashx?action=GetMorePhoto&StyleID="+id
      item_json_data = JSON.parse(Curl.get(url).body)

      item_json_data.each do |img|
        all_images.push(img['imgXL'])
      end
      all_images
    end

    def has_more_info
      true
    end

  end
end