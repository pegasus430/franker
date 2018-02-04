class Cj < StoreAPI

  DEVELOPER_KEY = "009b8e7c62eb29289f2aacbfdb456edb3d88761d16ba9e689dd5b88539eddd962a4eb83da499f4931efa7ab450a6ced382d20e80de76d7015c5870c465d0fcba8d/0efbfdbd659bb45f08b45552e0f059cc269e0215536ab8f7234440092181abda4688b0c99a53abd5ed10f5d15ea11cd7be19be77ce639c0e0df6c315fbe730bd"
  WEBSITE_ID = 7647968

  class << self
    def products(advertiser_id, page_no)
      client = CommissionJunction.new(Cj::DEVELOPER_KEY, Cj::WEBSITE_ID)
      client.product_search('advertiser-ids' => advertiser_id, 'records-per-page' => '1000', 'page-number' => page_no)
    end

    def create_items(store, advertiser_id, categories=nil)
      @store = store
      products_hash = products(advertiser_id, 1)
      total_products_count = products_hash[:total_number_of_products]
      total_pages = (total_products_count.to_f / 1000).ceil
      import_keys = []
      if total_pages.present?
        (1..total_pages).each do |page_no|
          puts "Running page #{page_no} / #{total_pages}"
          num_items_added = 0
          products = products(advertiser_id, page_no)[:products]
          products.each do |product|
            if product.advertiser_category.present?
              category_name = product.advertiser_category.split("> ").last.gsub(/&amp;|&gt;/, '')
              unless (!category_name.downcase.include?("womens")) && (category_name.downcase.include?("mens") || category_name.downcase.include?("boys"))
                if (!categories.present?) || categories.include?(category_name)
                  import_key = import_data(product, @store)
                  unless import_key.nil?
                    num_items_added = num_items_added + 1
                    import_keys << import_key
                  end
                end
              end
            else
              import_key = import_data(product, @store)
              unless import_key.nil?
                num_items_added = num_items_added + 1
                import_keys << import_key
              end
            end
          end
          puts "Added #{num_items_added} from page #{page_no}"
        end
      else
        products = products_hash[:products]
        products.each do |product|
          import_key = import_data(product, @store)
          import_keys << debug_import_key(store, product) unless import_key.nil?
        end
      end
      
      make_items_sold(import_keys, @store)
      complete_item_creation(@store)
    end

    def debug_import_key(store, product)
      if product.image_url.present?
        if product.image_url.split('/')[-1] == "nophoto"
          return "#{store.name.downcase.split(' ').join('')}_#{product.image_url.split('/')[-2].split("?")[0].split(".")[0]}"
        else
          return "#{store.name.downcase.split(' ').join('')}_#{product.image_url.split('/')[-1].split("?")[0].split(".")[0]}"
        end
      end
    end

    def import_data(product, store)
      if product.advertiser_category.present?
        category_name = product.advertiser_category.split("> ").last.gsub(/&amp;|&gt;/, '')
        unless (!category_name.downcase.include?("womens")) && (category_name.downcase.include?("mens") || category_name.downcase.include?("boys"))
          category = store.categories.find_or_initialize_by(name: category_name, overall_category: false, category_type: "External")
          category.url =""
          category.save
        end
      end
      
      item_name = corrected_name(product.name)
      unless should_save_item_with_name(item_name)
        return nil
      end
      
      import_key = debug_import_key(store, product)
      if import_key.nil?
        return nil
      end
      
      price = 0
      msrp = 0
      if product.sale_price.present?
        price = product.sale_price
        msrp = (product.retail_price ? product.retail_price : product.price)
        msrp ||= '0'
      else
        price = product.price
        msrp = (product.retail_price ? product.retail_price : "0")
      end
      price = convert_to_cents(price)
      msrp = convert_to_cents(msrp)
      if (price > msrp) || price == 0
        old_msrp = msrp
        msrp = price
        price = old_msrp
      end
      sold_out = product.in_stock ? false : true
      item_url = product.buy_url
      image_url = product.image_url
      
      colors = nil
      if has_more_info && (!sold_out)
        more_info_dict = scrape_more_info(import_key, product, import_key.split("_")[1], item_url)
        if more_info_dict[:prices].present?
          price = more_info_dict[:prices][0]
          msrp = more_info_dict[:prices][1]
        end
      end
      
      @item = store.items.find_or_initialize_by(import_key: import_key)
      if @item.persisted?
        update_item(@item, store, category, item_url, price, msrp, nil, colors, image_url)
      else
        create_new_item(@item, store, category, import_key, image_url, item_url, item_name, price, msrp, DateTime.now, nil, more_info_dict[:colors], sold_out)
      end
      if @item.persisted? && has_more_info
        update_more_info(@item, [], more_info_dict[:description], more_info_dict[:more_info])
      end
      import_key = @item.persisted? ? import_key : nil
      import_key
    end

    def corrected_name(name)
      name
    end

    def should_save_item_with_name(name)
      is_male_product = (!name.downcase.include?("womens")) && (name.downcase.include?("mens") || name.downcase.include?("boys"))
      !is_male_product
    end
    
    def build_color_item_url(item_url, color_identifier)
      item_url.sub(/[A-Z0-9]{7,9}-[A-Z0-9]{3,5}-[A-Z0-9]{3,5}-[A-Z0-9]{3,5}-[A-Z0-9]{11,12}/, color_identifier)
    end

    def build_images_for_color swatch_url
      ("a".."d").map { |alphabet| swatch_url.gsub("$swatch$","$detail-item$").gsub("swatch", alphabet) }
    end
    
    #############################
    ######### More Info #########
    #############################
    def has_more_info
      false
    end
    
    def scrape_more_info(item_import_key, product_cj_obj, product_code, item_url)
      colors_info = []
      item_url = URI.decode(product_cj_obj.buy_url.split("url=").second)
      begin
        item_doc = Nokogiri::HTML(open(item_url))
      rescue Exception => e
        puts "^" * 40
        puts "Error: #{e}"
        puts "Error At opening item URL: #{item_url}"
        puts "^" * 40
      end
      
      description = ''
      more_info = []
      if item_doc.present?
        desc_tag = item_doc.at_css(".long-desc > text()")
        description = desc_tag.present? ? desc_tag.text.strip : nil
        more_info_tag = item_doc.at_css(".care-desc")
        more_info_tag_text = more_info_tag.present? ? more_info_tag.text : ""
        more_info = more_info_tag_text.delete("*").split("\r\n").reject(&:empty?)
        if item_doc.css(".product-option.color-options ul li img").count > 0
          item_doc.css(".product-option.color-options ul li img").each do |color|
            color_image_url = color.attr("src")
            color_name = color.attr("alt")
            # Gets images
            images = build_images_for_color(color_image_url)

            # Finds Color Url by substituting FreePeople-item-color-ID in Item Url
            color_identifier = color.parent.attr('rel')
            color_item_url = build_color_item_url(item_url, color_identifier)

            sizes_body = item_doc.at_css(".sizes-#{color_identifier}")
            if sizes_body.nil?
              sizes_array = []
              puts "ERROR: #{item_url} failed to parse through sizes"
            else
              sizes_array = sizes_body.css("li").map { |li| li.css("span").text if li.attr("class") == "instock" }.compact
            end

            # builds import key for color.
            color_code = color_image_url.split("/")[-1].split("_").second # contains color uniq id
            import_key = "#{item_import_key}_#{color_code}"

            colors_info << { color: color_name,
                             sizes: sizes_array,
                             color_item_url: color_item_url,
                             images: images,
                             import_key: import_key }
          end
        else
          # Item may only have 1 color with no swatches
          color = item_doc.css(".product-option.color-options")
          if color.present?
            color_name = color.css("dl dd").text
            # Finds Color Url by substituting FreePeople-item-color-ID in Item Url
            color_identifier = color.css("input").attr('value')
            sizes_body = item_doc.at_css(".sizes-#{color_identifier}")
            if sizes_body.nil?
              sizes_array = []
              puts "ERROR FOUND: #{item_url} failed to parse through sizes"
            else
              sizes_array = sizes_body.css("li").map { |li| li.css("span").text if li.attr("class") == "instock" }.compact
            end
            
            import_key = item_import_key
            images = item_doc.css(".product-images ul li img").map {|i| i["src"] + "$detail-item$" }[1..-1]
            colors_info << { color: color_name,
                           sizes: sizes_array,
                           color_item_url: item_url,
                           images: images,
                           import_key: import_key }
          end
        end
      end
      return {colors: colors_info, description: description, more_info: more_info}
    end
    
    # def send_notification(store)
      # unless store.name == "Anthropologie"
        # User.non_admin.find_each do |user|
          # if user.stores.include?(store)
            # message = "There are new markdowns from #{store.name}. Check them out while they last!"
            # n = user.notifications.find_or_create_by(message: message, notification_type: "new_items", seen: false, priority: 2)
            # n.custom_data = {store_id: store.id, type: "new_items"}
            # n.save
          # end
        # end
      # end
    # end
  end
end
