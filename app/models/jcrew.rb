class Jcrew < StoreAPI
  class << self

    TYPE_OF_PRODUCTS_VIEW = {
      normal: [ "SHIRTS & TOPS",
                "SWEATERS",
                "SUITING",
                "DRESSES",
                "SKIRTS",
                "OUTERWEAR",
                "BEACH COVER-UPS",
                "SLEEPWEAR",
                "SHOES",
                "BAGS",
                "ACCESSORIES",
                "SHORTS",
                "KNITS & TEES",
                ],
        plus: [ "SWIM", "DENIM", "PANTS", "JEWELRY"]
    }

    def store_items(items_sold=false)
      @store  = Store.where(name: "J Crew").last
      @categories = @store.categories.external.where.not(url: nil)
      created_at = DateTime.now
      @categories.each do |category|
        puts "JCrew Category URL: #{category.url}"
        items = []
        cat_doc = Nokogiri::HTML(open("#{category.url}?iNextCategory=-1"))
        if TYPE_OF_PRODUCTS_VIEW[:plus].include?(category.name)          
          product_detail_urls = parse_products_plus(cat_doc)          
          product_detail_urls.each do |product_detail_url|
            begin
              items << parse_product_detail(product_detail_url)
            rescue
              next
            end
          end
        else
          product_detail_urls = parse_products_normal(cat_doc)
          product_detail_urls.each do |product_detail_url|
            begin
              items << parse_product_detail(product_detail_url)
            rescue
              next
            end
          end
        end
        
        items.flatten!
        create_items(items, @store, category, created_at)  
      end
      complete_item_creation(@store)
    end
    
    # def clean_up_item_color(item_color, color_info)
      # if item_color.item.category_id < 49
        # return
      # end
      # begin
        # item_color.images.delete_all
        # item_color.image.delete unless item_color.image.nil?
#       
        # color_image = create_image(color_info[:image_url]) if color_info[:image_url].present? && !color_info[:image_url].nil?
        # color_image_id = color_image.present? ? color_image.id : nil
        # item_color.update(image_id: color_image_id)
        # create_multiple_images(color_info[:images], item_color.id, "ItemColor")
      # rescue
      # end
    # end

    def has_more_info
      true
    end

    private

      def parse_products_normal(category_doc)        
        category_doc.xpath('//td[contains(@class,"arrayProdCell")]//td[contains(@class, "arrayImg")]/a/@href').map(&:value)
      end
      
      def parse_products_plus(category_doc)
        category_doc.xpath('//div[@class="plus_detail_wrap"]//a/@href').map(&:value)
      end
      
      def parse_product_detail(product_detail_url)
        b = Watir::Browser.new(:phantomjs)
        b.goto product_detail_url
        b.goto product_detail_url  ## for avoiding popup window it will remove cookies
        prod_doc = Nokogiri::HTML(b.html)
        
        begin
          articles = []        
          if prod_doc.css(".product-detail-container article").length == 1
            articles << prod_doc.css(".product-detail-container article")
          else
            articles = prod_doc.css(".product-detail-container article")
          end

          items = []
          articles.each_with_index do |article_doc, article_doc_index|
            next if article_doc.css('.sold-out').present?

            name = article_doc.css("section#description#{article_doc_index} h1").try(:text).strip
            description = article_doc.css('.product-detail-main-img .notranslate').try(:text).strip
            price = article_doc.css('.product-detail-sku .full-price')[0].try(:text).strip
            msrp = article_doc.css(".product-detail-sku .selected-color-price")[0].try(:text)
            msrp.strip! unless msrp.nil?
            image_url = article_doc.css("#pdpMainImg#{article_doc_index}").attr('src').try(:text)
            data_product_code = article_doc.css("#pdpMainImg#{article_doc_index}").attr('data-productcode')
            import_key = "jcrew_#{data_product_code}"
            
            color_ids = []
            color_import_keys = []   
            color_swatches = []       
            article_doc.css('.product-detail-sku section.color-row .color-box').each do |color_box|
              color_id = color_box.css("a").attr("id").text
              color_ids << color_id
              color_import_keys << "#{import_key}_#{color_id}"
              color_swatches << color_box.css("img").attr("src").text
            end
            secondary_images = []
            article_doc.css(".product-detail-main-img .product-detail-img div .float-left img").each do |item_image|
              image_file = item_image.attr("src").gsub("$pdp_tn75$", "$pdp_enlarge$")
              secondary_images << image_file
            end
            
            color_infos = []
            color_swatches.each_with_index do |swatch_url, color_swatch_index|
              begin
                images = []
                sizes = []
                b.img(:src => swatch_url).click              
                size_doc = Nokogiri::HTML(b.html)
                size_doc.css("#sizes#{article_doc_index} div.size-box").each do |size_box|
                  unless size_box.attr("class").include? "unavailable"
                    unless size_box.attr("data-size").nil?
                      sizes << size_box.attr("data-size")
                    end
                  end                
                end

                images << size_doc.css("#pdpMainImg#{article_doc_index}").attr("src").text.gsub("$pdp_fs418$", "$pdp_enlarge$")
                
                size_doc.css("#product#{article_doc_index} .product-detail-main-img .product-detail-img div .float-left img").each do |item_image|
                  image_file = item_image.attr("src").gsub("$pdp_tn75$", "$pdp_enlarge$")
                  images << image_file
                end
                color = size_doc.css("#product#{article_doc_index} .color-name").try(:text).strip                            
                color_infos << {import_key: color_import_keys[color_swatch_index], image_url: swatch_url, sizes: sizes, images: images, color: color}

              rescue Exception => e
                puts "^" * 40
                puts "ERROR: encountered error when scraping url: #{product_detail_url} with swatch_url: #{swatch_url}"
                puts "Error: #{e}"
                puts "^" * 40
              end
            end
            all_sizes = []
            color_infos.each do |color_info|
              if color_info[:sizes].present?
                color_info[:sizes].each do |size|
                  all_sizes << size unless all_sizes.include? size
                end
              end
            end   
            item_hash = {name: name, description: description, url: product_detail_url, price: price, image_url: image_url, import_key: import_key, secondary_images: secondary_images}
            item_hash = item_hash.merge(size: all_sizes)
            item_hash = item_hash.merge({colors: color_infos}) if color_infos.present?
            
            items << item_hash
          end

          close_browser(b)
        rescue Exception => e
          close_browser(b)
          puts "^" * 40
          puts "ERROR: encountered error when scraping url: #{product_detail_url}"
          puts "Error: #{e}"
          puts "^" * 40
        end

        items
      end

  end
end