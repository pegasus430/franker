class Adidas < StoreAPI
  class << self

    DOMAIN = 'http://www.adidas.com/us'
    TYPE_OF_PRODUCTS_VIEW = {
      customize: ['Basketball Shoes', 'Womens Softball Shoes'],
        normal: []
    }

    def store_items(items_sold=false)
      @store  = Store.where(name: "Adidas").last
      @categories = @store.categories.external.where.not(url: nil)
      created_at = DateTime.now
      
      @categories.each do |category|
        items = []        
        cat_doc = Nokogiri::HTML(open("#{category.url}?sz=120&start=0"))
        product_detail_urls = parse_products(cat_doc)
        
        total_page = get_total_page(cat_doc)
        cur_page = 0
        while cur_page < total_page          
          cur_page = cur_page + 1
          cat_doc = Nokogiri::HTML(open("#{category.url}?sz=120&start=#{cur_page*120}"))
          product_detail_urls = product_detail_urls | parse_products(cat_doc)
        end        
        next if TYPE_OF_PRODUCTS_VIEW[:customize].include?(category.name)          
        scrapped_import_keys = []
        product_detail_urls.each do |product_detail_url|
          product_sku = product_detail_url.split('/')[-1].match(/(.*)\.html/)[1]
          product_sku = "adidas_#{product_sku}"          
          next if scrapped_import_keys.include?(product_sku)        
          # next if is_product_key_imported(product_sku)  ## confirm sku on DB
          prod_infos = parse_product_detail(product_detail_url)
          scrapped_import_keys << prod_infos[:other_import_keys] if prod_infos[:other_import_keys].present?
          scrapped_import_keys.flatten!      
          items << prod_infos[:items] if prod_infos[:items].present?     
        end
        create_items(items.flatten, @store, category, created_at)        
      end
      complete_item_creation(@store)
    end
    
    def has_more_info
      true
    end

    private

      def parse_products(category_doc)
        category_doc.xpath('//div[contains(@class, "innercard")]/div[@class="image"]/a/@href').map(&:value)
      end
      
      def parse_product_detail(product_detail_url)        
        begin
          b = Watir::Browser.new(:phantomjs)          
          b.goto product_detail_url
          product_doc = Nokogiri::HTML(b.html)
          
          name = product_doc.xpath('//h1[@class="title-32 vmargin8"]').try(:text).strip
          desc = product_doc.xpath('//meta[@property="og:description"]/@content').text
          
          price = product_doc.at_css('#productInfo span.sale-price').try(:text).strip
          if product_doc.at_css('#productInfo span.baseprice').present?
            msrp = product_doc.at_css('#productInfo span.baseprice').try(:text).strip
          else
            msrp = price
          end

          more_info = product_doc.xpath('//segment[contains(@class, "ProductDescription")]//ul[@class="bullets_list para-small"]').try(:children).try(:map, &:text)
          image_url = product_doc.xpath('//meta[@property="og:image"]/@content').text
          secondary_images = []

          color_infos = []          

          product_sku = product_doc.xpath('//div[@id="main-section"]').attr('data-sku').text
          item_import_key = "adidas_#{product_sku}"
          
          import_keys = [item_import_key]
          color_info = {}
          
          swatch_tags = product_doc.xpath('//ul/li/div[contains(@class, "color-variations-thumb-color")]/a')
          if swatch_tags.present?          
            selected_swatch_tag = product_doc.xpath('//div[contains(@class, "color-variations-thumb-color")][contains(@class, "active")]/a')
            ordered_swatches = order_swatches(swatch_tags)
            
            ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
              color_info = {}
              if (swatch_tag_index > 0)
                b.goto "#{DOMAIN}#{swatch_tag['href']}"
                
                product_doc = Nokogiri::HTML(b.html)

                swatch_price = product_doc.at_css('#productInfo span.sale-price').try(:text).strip
                if product_doc.at_css('#productInfo span.baseprice').present?
                  swatch_msrp = product_doc.at_css('#productInfo span.baseprice').try(:text).strip
                else
                  swatch_msrp = swatch_price
                end
                
                ### Each Color Item has different price
                next if swatch_msrp != msrp || swatch_price != price

                product_id = swatch_tag.parent['data-sku']
                import_key = "adidas_#{product_id}"
                unless import_keys.include? import_key
                  import_keys << import_key
                end
              end
              
              sizes_tags = product_doc.xpath('//select[@name="pid"]/option')
              color_info[:sizes] = []

              color_info[:color_item_url] = product_detail_url

              if sizes_tags.present?
                sizes_tags.each do |size_tag|
                  next if size_tag['value'] == 'empty'                
                  color_info[:sizes] << size_tag.text.strip
                end
              else
                color_info[:sizes] = ['One Size']
              end

              image_urls = product_doc.xpath('//ul[@class="pdp-image-carousel-list"]/li/img/@src').map(&:text)
              color_info[:image_url] = image_urls[0]
              
              if swatch_tag.present?
                color_info[:color] = swatch_tag['title'].strip
              else
                color_info[:color] = product_doc.xpath('//div[@class="product-color para-small"]').try(:text).strip
                nbsp = Nokogiri::HTML("&nbsp;").text
                color_info[:color] = color_info[:color].gsub(/^Color/, '').gsub(/\(.*\)/, '').gsub(nbsp, '').strip
              end

              color_id = swatch_tag.parent['data-sku']
              color_info[:import_key] = "#{item_import_key}_#{color_id}"

              color_info[:images] = []          
              image_urls.each do |image_url|
                color_info[:images] <<  image_url.gsub(/\?sw=\d+/, "?sw=800")
              end     
              color_infos << color_info
            end
          else
            sizes_tags = product_doc.xpath('//select[@name="pid"]/option')
            color_info[:sizes] = []
            color_info[:color_item_url] = product_detail_url
            if sizes_tags.present?
              sizes_tags.each do |size_tag|
                next if size_tag['value'] == 'empty'                
                color_info[:sizes] << size_tag.text.strip
              end
            else
              color_info[:sizes] = ['One Size']
            end

            image_urls = product_doc.xpath('//ul[@class="pdp-image-carousel-list"]/li/img/@src').map(&:text)
            color_info[:image_url] = image_urls[0]
            color_info[:color] = product_doc.xpath('//div[@class="product-color para-small"]').try(:text).strip
            
            nbsp = Nokogiri::HTML("&nbsp;").text
            color_info[:color] = color_info[:color].gsub(/^Color/, '').gsub(/\(.*\)/, '').gsub(nbsp, '').strip
          
            color_id = product_sku
            color_info[:import_key] = "#{item_import_key}_#{color_id}"

            color_info[:images] = []          
            image_urls.each do |image_url|
              color_info[:images] <<  image_url.gsub(/\?sw=\d+/, "?sw=800")
            end     
            color_infos << color_info          
          end
        
        close_browser(b)
        all_sizes = []
        color_infos.each do |color_info|
          all_sizes = all_sizes | color_info[:sizes]
        end
        
        return {items: [{ 
          name: name, 
          description: desc, 
          url: product_detail_url,
          price: price,
          msrp: msrp,
          image_url: image_url,
          secondary_images: secondary_images,
          size: all_sizes, 
          more_info: more_info,
          import_key: item_import_key,
          colors: color_infos
        }], other_import_keys: import_keys}
        rescue Exception => e
          puts '^' * 40
          puts "ERROR: Failed to fully scrape item with url: #{product_detail_url}"
          puts "Error: #{e}"
          puts '^' * 40
        end
        return {}
      end

      def get_total_page(category_doc)
        total_page_tag = category_doc.xpath('//li[@class="paging-total"]')
        if total_page_tag.present?
          total_page = total_page_tag.text.strip.match(/of (\d+)/)[1]
          total_page = total_page.to_i
        else
          total_page = 1
        end
        total_page
      end

      def order_swatches(swatch_tags)
        ordered_swatches = []
        color_ids = []
        if swatch_tags.count > 1
          selected_index = -1
          swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
            next unless swatch_tag.parent['class'].include?('active')
            selected_index = swatch_tag_index
            ordered_swatches << swatch_tag
            color_ids << swatch_tag.parent['data-sku']
            break          
          end
          
          swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
            next if selected_index == swatch_tag_index
            color_id = swatch_tag.parent['data-sku']
            unless color_ids.include? color_id
              ordered_swatches << swatch_tag
              color_ids << color_id
            end          
          end
        else
          ordered_swatches = swatch_tags
        end
        ordered_swatches
      end

      def is_product_key_imported(product_sku)
        @store  = Store.where(name: "Adidas").last
        item = @store.items.where(import_key: "adidas_#{product_sku}")
        return true if item.present?
        item_colors = ItemColor.where("import_key LIKE ? ", "adidas%").where("import_key LIKE ? ", "%#{product_sku}%")
        item_colors.present?
      end

  end
end