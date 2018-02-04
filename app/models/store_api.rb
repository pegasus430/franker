require "open-uri"

class StoreAPI < ActiveRecord::Base

  class << self
    def my_logger
      @@my_logger ||= Logger.new("#{Rails.root}/log/favorite_items.log")
    end

    def create_items(items, store, category, created_at, should_make_items_sold=true)
      puts "!" * 20
      puts "Creating Items: #{items.size}"
      @item_creation = false

      if should_make_items_sold
        import_keys = items.flat_map {|i| i[:new_import_key].present? ? i[:new_import_key] : i[:import_key] }.compact
        make_items_sold(import_keys, store, category)
      end
      
      if category.nil?
        return
      end
      
      category.items.where(store_id: nil).update_all(store_id: category.store_id)
      puts "$" * 30
      puts "Current Category Items Count : #{category.items.count}"
      puts "Items from retailer site Count : #{items.count}"
      puts "$" * 30
      items.each do |item|
        Librato.timing 'store_api.item.time' do
          if item.present? && item[:import_key].present?
            import_key = item[:new_import_key].present? ? item[:new_import_key] : item[:import_key]
            @item = store.items.includes(:category, :image).find_or_initialize_by(import_key: import_key)
            price = convert_to_cents(item[:price])
            msrp = convert_to_cents(item[:msrp])
            if @item.present? && @item.persisted?
              unless @item.image.present? && @item.image.file.present? && @item.image.file.url.present?
                if @item.import_key == item[:import_key]
                  puts "Creating Image and Item Present !!!!!!!"
                  @image = create_image(item[:image_url])
                  if @image.present?
                    @item.update(image_id: @image.id)
                  end
                end
              end
              secondary_images = item[:secondary_images].present? ? item[:secondary_images] : nil
              colors = item[:colors].present? ? item[:colors] : nil
              
              update_item(@item, store, category, item[:url], price, msrp, secondary_images, colors)
            else
              import_key = item[:new_import_key].present? ? item[:new_import_key] : item[:import_key]
              secondary_images = item[:secondary_images].present? ? item[:secondary_images] : nil
              colors = item[:colors].present? ? item[:colors] : nil
              create_new_item(@item, store, category, import_key, item[:image_url], item[:url], item[:name], price, msrp, created_at, secondary_images, colors)            
              @item_creation = true

            end
            update_more_info(@item, item[:size], item[:description], item[:more_info]) if @item.present? && @item.persisted?
            puts ""
          end
        end
      end
      puts "$" * 30
      puts "---------- Category Completed --------------"
      puts "Current Category Items Count : #{category.items.count}"
      puts "Items from retailer site Count : #{items.count}"
      puts "---------- Category Completed ENDS --------------"
      puts "$" * 30
      puts ""
      return @item_creation
    end
    
    def create_new_item(item, store, category, import_key, image_url, item_url, item_name, price, msrp, created_at, secondary_images, colors, sold_out=false)
      puts "Creating Image !!!!!!!"
      puts "Import Key: #{import_key}"
      @image = create_image(image_url)
      if (!@image.nil?) && @image.persisted?
        active = @image.file.url.present? ? true : false
        item.update(image_id: @image.id, url: item_url, name: item_name, price: price, msrp: msrp, active: active, store_id: store.id, category_id: category.id, new_one: true, created_at: created_at, import_key: import_key, sold_out: sold_out)
        unless sold_out
          Librato.timing 'store_api.create_images.time' do
            if has_more_info && secondary_images.present? && (!secondary_images.empty?) && @item.images.empty?
              create_multiple_images(secondary_images, @item.id, "Item")
            end
            if has_more_info && colors.present?
              update_item_colors(colors, @item)
            end
          end
        end
        puts "#" * 30
        puts "Item Created and Object: #{@item.inspect}"
        puts "#" * 30
        @item
      else
        puts "^" * 40
        puts "ERROR: Did not persist image with url: #{image_url} thus not creating item"
        puts "^" * 40
      end
    end
    
    def update_item(item, store, category, item_url, price, msrp, secondary_images, colors, image_url=nil, item_name=nil)
      puts "@" * 20
      puts "Updating Item: #{item.inspect}"
      puts "Category Details : Name: #{category.name}, ID: #{category.id}"
      puts "@" * 20
      item.update(category_id: category.id, url: item_url)
      check_for_price_change(item, price, msrp, category)
      clean_up_item(item, image_url)
      
      unless item_name.nil?
        item.update(name: item_name)
      end
            
      Librato.timing 'store_api.create_images.time' do
        if has_more_info && secondary_images.present? && (!secondary_images.empty?) && @item.images.empty?
          create_multiple_images(secondary_images, @item.id, "Item")
        end
        
        if has_more_info && colors.present?
          update_item_colors(colors, @item)
        else
          update_item_activation(item)
        end
      end
    end
    
    def make_items_sold(import_keys, store, category=nil)
      if category.nil?
        puts "Make Items Sold"
        items_that_are_now_sold_out = store.items.where.not(import_key: import_keys).where(sold_out: false)
        puts " Making #{items_that_are_now_sold_out.size} items sold out"
        items_that_are_now_sold_out.update_all(sold_out: true)
        items_that_are_now_sold_out.each do |item|
          if item.present? && item.persisted?
            AlgoliaWorker.delete_item_from_algolia(item)
          end
        end
        store.items.where(import_key: import_keys).update_all(sold_out: false)
      else
        puts "Make Items Sold for category with id: #{category.id}"
        Item.where(import_key: import_keys).update_all(category_id: category.id)
      
        items_that_are_now_sold_out = category.items.where.not(import_key: import_keys).where(sold_out: false)
        puts " Making #{items_that_are_now_sold_out.size} items sold out"
        items_that_are_now_sold_out.update_all(sold_out: true)
        items_that_are_now_sold_out.each do |item|
          if item.present? && item.persisted?
            AlgoliaWorker.delete_item_from_algolia(item)
          end
        end
        # update all items with given import_keys to not sold out
        items_that_are_now_not_sold_out = category.items.where(import_key: import_keys)
        puts " Making #{items_that_are_now_not_sold_out.size} items NOT sold out"
        items_that_are_now_not_sold_out.update_all(sold_out: false)
      end
    end
    
    def make_items_sold_given_items(items, store, category=nil)
      import_keys = items.flat_map {|i| i[:new_import_key].present? ? i[:new_import_key] : i[:import_key] }.compact
      puts "Number of import keys: #{import_keys}"
      make_items_sold(import_keys, store, category)
    end
    
    def complete_item_creation(store)
      store.items_updated_at = DateTime.now
      store.save
    end
    
    def close_browser(b)
      begin
        b.close unless b.nil?
      rescue
      end
    end
    
    #############################
    ######### More Info #########
    #############################
    def has_more_info
      false
    end
    
    def update_more_info_for_items(items, store, category)
      puts "$" * 30
      puts "Current Category Items Count : #{category.items.count}"
      puts "Items from retailer site Count : #{items.count}"
      puts "$" * 30
      items.each do |item|
        Librato.timing 'store_api.item.time' do
          if item.present? && item[:import_key].present?
            import_key = item[:new_import_key].present? ? item[:new_import_key] : item[:import_key]
            @item = store.items.includes(:category, :image).find_by(import_key: import_key)
            if @item.present? && @item.image.present? && @item.image.file.url.present? && category.present?
              Librato.timing 'store_api.create_images.time' do
                if has_more_info && item[:secondary_images].present? && @item.images.count < item[:secondary_images].count   # todo: remove secondary_images column
                  create_multiple_images(item[:secondary_images], @item.id, "Item")
                end
                if has_more_info && item[:colors].present?
                  update_item_colors(item[:colors], @item)
                else
                  update_item_activation(item)
                end
              end
              update_more_info(@item, item[:size], item[:description], item[:more_info])
            end
          end
        end
      end
    end
    
    def update_more_info(item, sizes, description, more_info)
      if has_more_info && description.present?
        stripped_more_info = []
        unless more_info.nil?
          more_info.each do |info|
            stripped_more_info << info.strip
          end
          more_info = stripped_more_info
        end
        more_info = more_info.present? ? more_info.uniq.reject(&:empty?) : []
        size = sizes.present? ? sizes.reject(&:empty?) : []
        begin
          item.update(description: description.strip, more_info: more_info, size: size)
        rescue Exception => e
          puts "^" * 40
          puts "ERORR: failed to update item #{item.inspect}"
          puts "^" * 40
        end
        AlgoliaWorker.add_item_to_algolia(item)
      end
    end
    
    def create_item_color(color_info, item)
      @color_image = create_image(color_info[:image_url]) if color_info[:image_url].present? && !color_info[:image_url].nil?
      color_image_id = @color_image.present? ? @color_image.id : nil

      if color_info[:color].present? || color_image_id.present?
        @item_color = ItemColor.find_or_initialize_by(import_key: color_info[:import_key])
        @item_color.update(url: color_info[:color_item_url], sizes: color_info[:sizes], image_id: color_image_id, item_id: item.id)
        @item_color.update(rgb: color_info[:rgb]) if color_info[:rgb].present?
        @item_color.update(color: color_info[:color]) if color_info[:color].present?
        create_multiple_images(color_info[:images], @item_color.id, "ItemColor")
      end
      if @item_color.present? && @item_color.persisted?
        puts "~" * 20
        puts "Created item color: #{@item_color.inspect}"
        puts "~" * 20
      else
        puts "^" * 40
        puts "ERROR: Failed to create item color with info: #{color_info} for item: #{item}"
        puts "^" * 40
        @item_color = nil
      end

      @color_image = nil
      color_info = []
      @item_color
    end

    def update_item_colors(color_infos, item)
      color_infos.each do |color_info|
        item_color = ItemColor.find_by(import_key: color_info[:import_key])
        if item_color.nil?
          item_color = create_item_color(color_info, item)
        else
          should_redownload_image = item_color.image_id.nil? || item_color.image.nil? || item_color.image.file.nil?
          image_id = item_color.image_id
          if should_redownload_image && color_info[:image_url].present? && !color_info[:image_url].nil?
            color_image = create_image(color_info[:image_url])
            image_id = color_image.id if color_image.present?
          end
          if item_color.images.count == 0
            create_multiple_images(color_info[:images], item_color.id, "ItemColor")
          end
          if color_info[:color].present?
            item_color.update(url: color_info[:color_item_url], sizes: color_info[:sizes], item_id: item.id, import_key: color_info[:import_key], color: color_info[:color], image_id: image_id)
          else
            item_color.update(url: color_info[:color_item_url], sizes: color_info[:sizes], item_id: item.id, import_key: color_info[:import_key], image_id: image_id)
          end
          item_color.update(rgb: color_info[:rgb]) if color_info[:rgb].present?
          clean_up_item_color(item_color, color_info)
        end
        if item_color.present?
          update_item_color_activation(item_color)
          puts "~" * 20
          puts "Updated item color: #{item_color.inspect}"
          puts "~" * 20
        end
      end
      
      color_import_keys = []
      color_infos.each do |color_info|
        color_import_keys << color_info[:import_key]
      end
      ItemColor.where(item_id: item.id, active: true).where.not(import_key: color_import_keys).update_all(active: false)
      update_item_activation(item)
    end

    def update_item_color_activation(item_color)
      if item_color.sizes.empty? || item_color.images.count == 0 || (item_color.color.blank? && item_color.image_id.blank?)
        item_color.update(active: false)
      else
        item_color.update(active: true)
      end
    end
    
    def update_item_activation(item)
      item.image_id.present? && (!has_more_info || item.item_colors.active.count > 0) ? item.update(active: true) : item.update(active: false)
    end
    
    def clean_up_item_color(item_color, color_info)
      # do nothing
    end
    
    def clean_up_item(item, image_url)
      # do nothing
    end
    
    def make_items_and_sizes_sold(items, store, category)
      puts "make_items_and_sizes_sold"
      import_keys = items.flat_map {|i| i[:new_import_key].present? ? i[:new_import_key] : i[:import_key] }.compact
      make_items_sold(import_keys, store, category)
      
      color_import_keys = []
      items.each do |item|
        if item[:colors].present? && item[:colors].count > 0
          item[:colors].each do |color_info|
            item_color = ItemColor.find_by(import_key: color_info[:import_key])
            if item_color.present?
              item_color.update(sizes: color_info[:sizes])
              puts "Updated size information: #{item_color.inspect}"
            end
            color_import_keys << color_info[:import_key] if color_info[:import_key].present?
          end
        end
      end
      
      item_ids = category.items.where(sold_out: false).pluck(:id)
      ItemColor.where(item_id: item_ids, import_key: color_import_keys).each do |item_color|
        item_color.update(active: item_color.sizes.count > 0)
      end
      ItemColor.where(item_id: item_ids, active: true).where.not(import_key: color_import_keys).update_all(active: false)
      
      category.items.where(sold_out: false).find_each do |item|
        item.item_colors.active.count > 0 ? item.update(active: true) : item.update(active: false)
      end
    end
    
    ############################
    ###### Image Creation ######
    ############################
    def create_image(url)
      @image = Image.new
      @image.remote_file_url = url
      begin
        @image.save!
        Curl.get(@image.file.url)
      rescue Exception => e
        puts "^" * 40
        puts "Exception Occurred for Image Creation - create_image"
        puts "Image Url : #{url}"
        puts "Image Details : #{@image.inspect}"
        puts "Error: #{e}"
        puts "^" * 40
        unless @image.nil?
          @image.destroy
          @image = nil
        end
      end
      @image
    end

    def create_multiple_images(urls, imageable_id, type)
      if urls.present? && urls.count > 0  
        urls.each do |url|          
          begin
            @image = Image.new(imageable_type: type, imageable_id: imageable_id)
            @image.remote_file_url = url
            @image.save!
            Curl.get(@image.file.url)
          rescue Exception => e
            puts "^" * 40
            puts "Exception Occurred for Image Creation - create_multiple_images"
            puts "Item Url : #{url} imageable_id: #{imageable_id} type: #{type}"
            puts "Image Details : #{@image.inspect}"
            puts "Error: #{e}"
            puts "^" * 40
            unless @image.nil?
              @image.destroy
              @image = nil
            end
          end
          @image
        end
      end
    end
    
    #############################
    ####### Price Helpers #######
    #############################
    def convert_to_cents(price)
      price = (price.present? && price != 0) ? price.gsub(/[^\d\.]/, '').to_f * 100 : 0
      price.to_i
    end

    def get_common_prices(item)
      price_text = item.at_css("td.arrayCopy .arrayProdPrice").text
      prices = price_text.scan(/[.,\d]+/).flatten
      sales_price_text = item.at_css("td.arrayCopy .arrayProdSalePrice").text.scan(/[.,\d]+/) if item.at_css("td.arrayCopy .arrayProdSalePrice").present?
      if prices[1].present?
        msrp = "$" + prices[0]
        price = "$" + prices[1]
      elsif sales_price_text.present?
        msrp = "$" + prices[0]
        price = "$" + sales_price_text.flatten[0]
      else
        msrp = "$0"
        price = "$" + prices[0]
      end
      {price: price, msrp: msrp}
    end
    
    def price_from_off_percent(price, off_percent)
      (price.to_f * ((100-off_percent).to_f/100)).round(2)
    end
    
    def check_for_price_change(item, price, msrp, category)
      item.update(price: price, msrp: msrp) if item.price != price || item.msrp != msrp
      # if (item.price == item.msrp || msrp == 0) && category.special_tag == ""
        # item.update(import_key: item_resp[:new_import_key].present? ? item_resp[:new_import_key] : item_resp[:import_key])
      # end

      # TODO: in future we may want to send a notification if the price is cheaper (e.g. was on sale but even bigger sale now)
      # if (msrp != 0 && item.sale? && !item.sold_out)
        # Librato.timing 'store_api.item_price_notification.time' do
          # begin
            # user_items = item.user_items.where(favorite: true, sale: false)
            # my_logger.info("*" * 10 + "Item Favorite Data" + "*" * 10)
            # my_logger.info("Item Details: #{item.inspect}, price: #{price}, msrp: #{msrp}")
            # my_logger.info("UserItems Count: #{user_items.count}")
            # if user_items.present?
              # user_items.update_all(sale: true)
              # make_item_favorite_notification(user_items, item) if item.active
              # my_logger.info("User Items Updated")
            # end
          # rescue Exception => e
            # puts "^" * 40
            # puts "Exception Occurred when setting up user_item push notifications"
            # puts "Error: #{e}"
            # puts "^" * 40
          # end
          # my_logger.info("*" * 10 + "End" + "*" * 10)
          # my_logger.info ""
        # end
      # end
    end
    
    ############################
    #### User Notifications ####
    ############################ 
    def make_item_favorite_notification(user_items, item)
      message = "#{item.name} from #{item.store.name} that you favorited just went on sale! Check it out now!"
      user_items.each do |user_item|
        if user_item.user.present?
          user = user_item.user
          my_logger.info("------------Item favorite Notification-----------")
          my_logger.info("Message: #{message}")
          n = user.notifications.find_or_create_by(message: message, notification_type: "favorite_item_sale", seen: false, priority: 1)
          n.custom_data = {type: "favorite_item_sale", item_id: item.id}
          n.save
          my_logger.info("UserItem Object: #{user_item.inspect}")
          my_logger.info("------------Notification Ends-----------")
          my_logger.info("")
        end
      end
    end
    
    def send_notification(store)
      unless store.name == "Anthropologie"
        User.non_admin.find_each do |user|
          if user.stores.include?(store)
            get_notifications(store, user)
          end
        end
      end
    end
    
    def get_notifications(store, user)
      message = get_messages(store, user)
      n = user.notifications.find_or_create_by(message: message, notification_type: "new_items", seen: false, priority: 2)
      n.custom_data = {store_id: store.id, type: "new_items"}
      n.save
    end
    
    def get_messages(store, user)
      messages = []
      sales_count = store.new_sale_items_count(user)
      items_count = store.new_items_count(user)
      if sales_count.present? && sales_count > 0
        m1 = "#{store.name} put #{sales_count} new items on sale today. Check them out while they last!"
        m2 = "#{sales_count} new sale items?! Better come check them while they still have your size!"
        m3 = "What's new today? #{store.name} just marked down #{sales_count} - Come and get 'em!"
        m4 = "#{Date.today.strftime('%A')} just got better. #{store.name} just marked down #{sales_count} items on sale today"
        m5 = "This sale is going fast! Shop the #{sales_count} new sale items from #{store.name} before they're all gone"
        m6 = "#{sales_count} #{store.name} must-haves are now on sale. Shop while it lasts!"
        m7 = "Everyone needs a little retail therapy. #{store.name} marked down #{sales_count} items on sale. Ready, set, shop!"
        m8 = "Mornings can be better. #{sales_count} new items on sale from #{store.name} Shop before they're all gone!"
      end
      messages << [m1, m2, m3, m4, m5, m6, m7, m8]
      if items_count.present? && items_count > 0
        m1 = "#{store.name} just released #{items_count} new items today! Come open the app to view!"
        m2 = "#{Date.today.strftime('%A')} just got better. Shop #{store.name} new arrivals. Come see what's new"
        m3 = "Stay fashion forward. Check out the #{items_count} new items from #{store.name}"
        m4 = "New Everything. #{items_count} new styles from #{store.name}"
        m5 = "Check out the latest new styles from #{store.name}. We've got #{items_count} for you to Dote!"
        m6 = "#{items_count} new must-haves from #{store.name}. Start shopping now!"
        m7 = "Get your style on. #{items_count} new items from #{store.name}. Take a look!"
        m8 = "#{items_count} new arrivals from #{store.name}. Start shopping on Dote!"
        m9 = "Good clothes/shoes take you good places. Let's take you to Dote with #{items_count} new items from #{store.name}"
        messages << [m1, m2, m3, m4, m5, m6, m7, m8, m9]
      end
      messages.flatten.compact.sample
    end

    def get_html_content(requested_url, limit = 10)
      begin
        url = URI.parse(requested_url)
        full_path = (url.query.blank?) ? url.path : "#{url.path}?#{url.query}"      
        the_request = Net::HTTP::Get.new(full_path, {'User-Agent' => 'DoteBot'})
       
        the_response = Net::HTTP.start(url.host, url.port) { |http|
          http.request(the_request)
        }
      rescue URI::InvalidURIError        
        host = requested_url.match(".+\:\/\/([^\/]+)")[1]
        path = requested_url.partition(host)[2] || "/"
        
        the_request = Net::HTTP::Get.new(path, {'User-Agent' => 'DoteBot'})   
        the_response = Net::HTTP.start(host, 80) { |http|
          http.request(the_request)
        }
      end
      if limit < 1
        return nil
      end
      case the_response
        when Net::HTTPSuccess     then the_response.body 
        when Net::HTTPRedirection then get_html_content(the_response['location'], limit - 1)
        else
        raise "Response was not 200, response was #{the_response}"
      end          
    end 
  end
end