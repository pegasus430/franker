class Nike < StoreAPI
  class << self

    DOMAIN = 'www.nike.com'
    
    def store_items(items_sold=false)
      @store  = Store.where(name: "Nike").last
      @categories = @store.categories.external.where.not(url: nil)
      created_at = DateTime.now
      
      @categories.each do |category|        
        Sidekiq.logger.info "Category URL : #{category.url}"        
        begin    
          cat_doc = Nokogiri::HTML(open("#{category.url}?ipp=500"))
          product_detail_urls = parse_products(cat_doc)
        rescue
          puts "Cannot open category url #{category.url}"
          next
        end
        items = []
        product_detail_urls.each do |product_detail_url|             
          prod_infos = parse_product_detail(product_detail_url)       
          next if prod_infos.empty?
          items << prod_infos             
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
        category_doc.xpath('//div[contains(@class, "grid-item-image")]//a/@href').map(&:value)
      end
      
      def parse_product_detail(product_detail_url)        
        begin
          b = Watir::Browser.new(:phantomjs)          
          b.goto product_detail_url
          product_doc = Nokogiri::HTML(b.html)
          
          return {} unless product_doc.xpath('//h1[contains(@class,"exp-product-title")]').present? ## If Video Product Url

          name = product_doc.xpath('//h1[contains(@class,"exp-product-title")]').try(:text).strip

          desc = product_doc.xpath('//div[@class="pi-pdpmainbody"]/p[position()=1]/b').try(:text).strip rescue ''
          
          price = product_doc.at_css('div.exp-product-info span.exp-pdp-local-price').try(:text).strip
          if product_doc.at_css('div.exp-product-info span.exp-pdp-overridden-local-price').present?
            msrp = product_doc.at_css('div.exp-product-info span.exp-pdp-overridden-local-price').try(:text).strip
          else
            msrp = price
          end

          more_info = product_doc.xpath('//div[@class="pi-pdpmainbody"]/p[position()>1]').try(:map, &:text) rescue []
          image_url = product_doc.xpath('//meta[@property="og:image"]/@content').text
          secondary_images = []

          color_infos = []          

          product_sku = product_detail_url.match(/pgid-(\d+)/)[1].strip
          item_import_key = "nike_#{product_sku}"
          
          import_keys = [item_import_key]
          color_info = {}
          
          swatch_tags = product_doc.xpath('//ul[contains(@class, "color-chip-container")][@data-status="IN_STOCK"]//a[contains(@href, "store.nike.com")]')
          
          if swatch_tags.present?
            ordered_swatches = order_swatches(swatch_tags)          
            ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
              color_info = {}
              if (swatch_tag_index > 0)
                b.goto swatch_tag['href']
                product_doc = Nokogiri::HTML(b.html)
              end
              
              sizes_tags = product_doc.xpath('//ul[contains(@class, "exp-pdp-size-dropdown")]/li')
              color_info[:sizes] = []

              color_info[:color_item_url] = swatch_tag['href']

              if sizes_tags.present?
                sizes_tags.each do |size_tag|
                  next if size_tag['class'].include?('exp-pdp-size-not-in-stock')
                  color_info[:sizes] << size_tag.text.strip
                end
              else
                color_info[:sizes] = ['One Size']
              end

              image_urls = product_doc.xpath('//ul[@class="exp-pdp-alt-images-carousel"]/li/img/@src').map(&:text)
              color_info[:image_url] = image_urls[0]
              
              color_info[:color] = product_doc.xpath('//span[@class="colorText"]').try(:text).strip
              
              color_id = swatch_tag['data-productid']
              color_info[:import_key] = "#{item_import_key}_#{color_id}"

              color_info[:images] = []          
              image_urls.each do |image_url|
                color_info[:images] <<  image_url.gsub("PDP_THUMB", "PDP_HERO")
              end     
              color_infos << color_info
            end
          else
            sizes_tags = product_doc.xpath('//ul[contains(@class, "exp-pdp-size-dropdown")]/li')
            color_info[:sizes] = []

            color_info[:color_item_url] = product_detail_url

            if sizes_tags.present?
              sizes_tags.each do |size_tag|
                next if size_tag['class'].include?('exp-pdp-size-not-in-stock')
                color_info[:sizes] << size_tag.text.strip
              end
            else
              color_info[:sizes] = ['One Size']
            end

            image_urls = product_doc.xpath('//ul[@class="exp-pdp-alt-images-carousel"]/li/img/@src').map(&:text)
            color_info[:image_url] = image_urls[0]
            
            color_info[:color] = product_doc.xpath('//span[@class="colorText"]').try(:text).strip
            
            color_id = "one_color"
            color_info[:import_key] = "#{item_import_key}_#{color_id}"

            color_info[:images] = []          
            image_urls.each do |image_url|
              color_info[:images] <<  image_url.gsub("PDP_THUMB", "PDP_HERO")
            end     
            color_infos << color_info
          end
        
        
          close_browser(b)
          all_sizes = []
          color_infos.each do |color_info|
            all_sizes = all_sizes | color_info[:sizes]
          end
        
          return { 
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
          }
        rescue Exception => e
          puts '^' * 40
          puts "ERROR: Failed to fully scrape item with url: #{product_detail_url}"
          puts "Error: #{e}"
          puts '^' * 40
        end
        return {}
      end

      def get_total_page(category_doc)
        return 1
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
            next unless swatch_tag.parent['class'].include?('selected')
            selected_index = swatch_tag_index
            ordered_swatches << swatch_tag
            color_ids << swatch_tag['data-productid']
            break          
          end
          
          swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
            next if selected_index == swatch_tag_index
            color_id = swatch_tag['data-productid']
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

  end
end