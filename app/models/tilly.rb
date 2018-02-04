class Tilly < StoreAPI

  ADVERTISER_ID = 1977127

  class << self

    def store_items
      @store = Store.find_by(name: "Tilly's")
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"
          @total = 0
          @index = 0
          begin
            begin
              @page_data = Nokogiri::HTML(open(category.url.try(:strip) + "?No=#{@index}&N=8bp", 'User-Agent' => 'DoteBot'))
            rescue Exception => e
              puts "^" * 40
              puts "Error At Opening Category URL: #{category.url}"
              puts "Error: #{e}"
              puts "^" * 40
              break
            end
            
            if not(@page_data.at_css(".products-container"))
              puts "^" * 40
              puts "Error No Results Found Page: #{category.url}"
              puts "^" * 40
              next
            end
            
            @total = @page_data.at_css(".products-container").attr("data-total-records").strip.to_i
            @records_per_page = @page_data.at_css(".products-container").attr("data-records-per-page").strip.to_i
            @current_page_records = @page_data.at_css(".products-container").attr("data-records-per-page").strip.to_i
            @items << fetch_tb_data(@page_data, category)
            @index = @index + @records_per_page            
          end while (@index) < @total
          
          @items.flatten!
          create_items(@items, @store, category, created_at)
        end
      end
      complete_item_creation(@store)
    end

    def prices_for(item)
      begin
        msrp = item.at_css(".prd-price-now").try(:text).to_s.strip.split[-1]
        price = item.at_css(".prd-price").try(:text).try(:squish)
        if price.include?("Was")
          price = price.split(" ")[2]      
        elsif msrp.present?
          price = msrp
          msrp = 0
        else
          price = item.at_css(".prd-price").try(:text).try(:squish).split[-1]
        end
        {msrp: msrp, price: price}
      rescue Exception => e
        return nil
      end
    end

    def image_url_for(item)
      item.at_css('.prd-img img').attr("src").gsub("medium","1000x1000")
    end

    def url_for(item)
      "http://www.tillys.com/" + item.at_css(".prd-name a").attr("href")
    end

    def name_for(item)
      item.at_css(".prd-name").text.strip
    end

    def fetch_tb_data(page_doc, category)
      data = []
      products = page_doc.css('.products-container .row  .prd-container.col-sm-3')
      products.each do |item|
        name = name_for(item)
        image_url = image_url_for(item)
        url = url_for(item)
        import_key = "tilly's_#{url.split("/")[-1]}"
        more_info_dict = get_more_info(import_key, url)
        
        prices = prices_for(item)
        if prices.nil?
          puts "^" * 40
          puts "ERROR retrieving prices for item at url: #{url}"
          puts "^" * 40
        else
          data << { name: name, import_key: import_key, image_url: image_url, url: url, description: more_info_dict[:description], size: more_info_dict[:size], colors:more_info_dict[:color_infos] }.merge(prices)
        end
      end
      data
    end  

    #############################
    ######### More Info #########
    #############################
    def has_more_info
      true
    end
    
    def get_more_info(item_import_key, item_url)
      color_infos, all_sizes = [], []
      description = nil
      # if saved_item_url.present? && saved_item_url.split("http://www.")[1].split(".")[0] == "tillys"
        # item_url = saved_item_url
      # else        
        # item_url = URI.decode(saved_item_url.split("url=").second)
      # end
      # if item_url.split("http://www.tillys.com/")[1].split("/").reject{|x| x if not x.present?}[0] != "intl"
        # item_url = "http://www.tillys.com/" + item_url.split("http://www.tillys.com/")[1].split("/").reject{|x| x if not(x.present?)}.join("/")      
        # item_url = "http://www.tillys.com/intl/" + item_url.split("http://www.tillys.com/tillys/")[1]
      # end
        
      begin
        item_doc = Nokogiri::HTML(open(item_url))
        item_body = item_doc.css("body").to_s
        product_hash = JSON.parse(item_body.scan(/var\ product\ =(.*);/)[0][0])
        color_hash = product_hash["sku"].inject({}){|hash, element|  hash[element["colorDescription"]] = {"sizes" => [] } if not(hash[element["colorDescription"]].present?);  hash[element["colorDescription"]]["sizes"] << element["size"];   hash[element["colorDescription"]]["img_url"] = "http://www.tillys.com/tillys/images/catalog/rollover/" + element["skuId"][0..-3] + ".jpg";  hash[element["colorDescription"]]["colorCD"] = element["colorCD"]; hash[element["colorDescription"]]["color_item_url"] = "http://www.tillys.com/intl/" + product_hash["seoUrl"].split("/")[0..-2].join("/") + "/" + element["colorCD"];  hash   }
      rescue Exception => e
        puts "^" * 40
        puts "Error At opening item url: #{item_url}"
        puts "Error: #{e}"
        puts "^" * 40
      end
      
      if item_doc.present?
        desc_tag = item_doc.at_css(".collapsible-container-content").try(:text).try(:squish).to_s.split("Size Chart")[0]
        if desc_tag.present?
          description = desc_tag.strip
        end
        
        if color_hash
          color_hash.each do |name, hash|
            color_image_url = hash["img_url"]
            color_name = name
            images = build_images_for_color(color_image_url)

            # Finds Color Url by substituting FreePeople-item-color-ID in Item Url
            color_identifier = hash["colorCD"]
            color_item_url = hash["color_item_url"]

            sizes_array = hash["sizes"]
            all_sizes << sizes_array

            # builds import key for color.
            color_code = color_image_url.split("/")[-1].split(".").first # contains color uniq id
            color_infos << { image_url: color_image_url,
                             sizes: sizes_array,
                             color: color_name,
                             color_item_url: color_item_url,
                             images: images,
                             import_key: "#{item_import_key}_#{color_code}" }
          end
        end
      end
      
      return {description: description, size: all_sizes.flatten.compact.uniq, color_infos: color_infos}
    end

    def build_images_for_color swatch_url
      letters = ('a'..'d').to_a.unshift('')
      letters << 'z'    
      letters.map { |alphabet| swatch_url.gsub("rollover","1000x1000").gsub(".jpg", "#{alphabet}.jpg") }
    end

  end
end