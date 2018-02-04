class ShopBop < StoreAPI
  class << self

    DOMAIN = 'www.shopbop.com'
    TYPE_OF_PRODUCTS_VIEW = {
      customize: [],
        normal: []
    }

    def store_items(items_sold=false)
      @store  = Store.where(name: "Shopbop").last
      @categories = @store.categories.external.where.not(url: nil)
      created_at = DateTime.now
      
      @categories.each do |category|
        next if category.url.nil? || category.url == "NA" || category.url.empty?        
        Sidekiq.logger.info "Category URL : #{category.url}"                       
        items = []        
        cat_doc = Nokogiri::HTML(open("#{category.url}?all"))
        
        total_page = get_total_page(cat_doc)
        
        product_detail_urls = []
        product_detail_urls = parse_products(cat_doc)

        cur_page = 1
        
        while cur_page < total_page          
          cat_doc = Nokogiri::HTML(open("#{category.url}?baseIndex=#{cur_page*100}&all"))
          product_detail_urls = product_detail_urls | parse_products(cat_doc)
          cur_page = cur_page + 1
          puts "Page: #{cur_page}  : #{product_detail_urls.count}"          
        end        
        product_detail_urls.each do |product_detail_url|
          items = []
          item = parse_product_detail(product_detail_url)
          items << item
          create_items(items.flatten, @store, category, created_at)
        end
      end
      complete_item_creation(@store)
    end
    
    def has_more_info
      true
    end

    private

      def parse_products(category_doc)
        urls = category_doc.xpath('//li[contains(@class, "hproduct")]/div[@class="border-container"]/a/@href').map(&:value)
        product_urls = []
        urls.each do |url|
          if url.include?('http')
            product_urls << url
          else
            product_urls << "http://#{DOMAIN}#{url}"
          end
        end
        product_urls
      end
      
      def parse_product_detail(product_detail_url)        
        Watir.default_timeout = 90
        begin
          puts "Product Detail Url: #{product_detail_url}"
          # b = Watir::Browser.new(:firefox)
          capabilities = Selenium::WebDriver::Remote::Capabilities.phantomjs("phantomjs.page.settings.userAgent" => "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1468.0 Safari/537.36")
          driver = Selenium::WebDriver.for :phantomjs, :desired_capabilities => capabilities
          b = ::Watir::Browser.new driver

          b.goto product_detail_url
          b.window.resize_to(800, 600)
          # b.screenshot.save ("/root/WORK/temp/shopbop3.png")

          product_doc = Nokogiri::HTML(b.html)
          
          name = product_doc.xpath('//span[contains(@class, "product-title")]').try(:text).strip
          desc = product_doc.xpath('//div[@itemprop="description"]').text
          
          if product_doc.xpath('//div[@id="product-information"]//span[@class="salePrice"]').present?
            price = product_doc.xpath('//div[@id="product-information"]//span[@class="salePrice"]').try(:text).strip
            msrp = product_doc.xpath('//div[@id="product-information"]//span[@class="originalRetailPrice"]').try(:text).strip
          else            
            price = product_doc.xpath('//div[@id="product-information"]//div[@class="priceBlock"]').try(:text).match(/([\d,\.]+)/)[1]
            msrp = price
            
          end          

          more_info = []
          image_url = product_doc.xpath('//ul[@id="thumbnailList"]/li[@class="thumbnailListItem"][position()=1]/img/@src').text
          secondary_images = []

          color_infos = []          

          product_sku = product_doc.xpath('//span[@id="productCode"]').attr('data-product-code').text
          item_import_key = "shopbop_#{product_sku}"
          
          
          color_info = {}
          
          swatch_tags = product_doc.xpath('//div[@id="swatches"]/img')
          
          if swatch_tags.present?
            ordered_swatches = order_swatches(swatch_tags)            
            ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
              color_info = {}
              if (swatch_tag_index > 0)
                b.execute_script("$('ul#thumbnailList li img').attr('src', '');")          
                b.img({id: swatch_tag['id']}).click
                b.element(:xpath => '//ul[@id="thumbnailList"]/li[@class="thumbnailListItem"]/img').wait_until_present                
                Watir::Wait.until { b.img(:xpath => '//ul[@id="thumbnailList"]/li[@class="thumbnailListItem"]/img[position()=1]').attribute_value('src').present? }
                product_doc = Nokogiri::HTML(b.html)
              end
              
              sizes_tags = product_doc.xpath('//div[@id="sizes"]/span')
              color_info[:sizes] = []

              color_info[:color_item_url] = product_detail_url

              if sizes_tags.present?
                sizes_tags.each do |size_tag|
                  next if size_tag['class'].include?('sizeUnavailable')
                  color_info[:sizes] << size_tag['data-selectedsize']
                end
              else
                color_info[:sizes] = ['One Size']
              end

              image_urls = product_doc.xpath('//ul[@id="thumbnailList"]/li[@class="thumbnailListItem"]/img/@src').map(&:text)
              color_info[:image_url] = swatch_tag['src']
              
              
              color_info[:color] = swatch_tag['alt']
              

              color_id = swatch_tag['id'].match(/swatchImage\.(\d+)/)[1]
              color_info[:import_key] = "#{item_import_key}_#{color_id}"

              color_info[:images] = []          
              image_urls.each do |image_url|
                color_info[:images] <<  image_url.gsub("._QL90_UX37_.jpg", ".jpg")
              end     
              color_infos << color_info
            end                 
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
        product_count = category_doc.xpath('//span[@id="product-count"]')
        total_page = 1
        if product_count.present?
          total_page = (product_count.text.strip.to_f / 100).ceil
        end
        total_page
      end

      def order_swatches(swatch_tags)
        ordered_swatches = []
        color_ids = []
        if swatch_tags.count > 1
          selected_index = -1
          swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
            next unless swatch_tag['class'].include?('swatchSelected')
            next if swatch_tag['class'].include?('swatchUnavailable')
            selected_index = swatch_tag_index
            ordered_swatches << swatch_tag
            color_ids << swatch_tag['id'].match(/swatchImage\.(\d+)/)[1]
            break          
          end
          
          swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
            next if swatch_tag['class'].include?('swatchUnavailable')
            next if selected_index == swatch_tag_index
            color_id = swatch_tag['id'].match(/swatchImage\.(\d+)/)[1]
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