class Ivivva < StoreAPI
  class << self

    DOMAIN = 'www.ivivva.com'

    def store_items(items_sold=false)
      @store  = Store.where(name: "Ivivva").last
      @categories = @store.categories.external.where.not(url: nil)
      created_at = DateTime.now
      
      @categories.each do |category|
        next if category.url.nil? || category.url == "NA" || category.url.empty?
        Sidekiq.logger.info "Category URL : #{category.url}"        
        items = []
        cat_doc = Nokogiri::HTML(open(category.url))
        product_detail_urls = parse_products(cat_doc)     
        product_detail_urls.each do |product_detail_url|       
          items << parse_product_detail(product_detail_url)       
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
        urls = category_doc.xpath('//div[contains(@class, "product")]//h3/a/@href').map(&:value)
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
        begin
          b = Watir::Browser.new(:phantomjs)          
          b.goto product_detail_url
          product_doc = Nokogiri::HTML(b.html)
          
          name = product_doc.at_css('#pageContent h1').try(:text).strip
          desc = product_doc.xpath('//meta[@name="description"]/@content').text rescue ''

          price = product_doc.xpath('//div[@id="price"]//span[@class="amount"][position()=1]').text.match(/([\d\.]+)/)[1]                        
          if product_doc.at_css('#price span.atg_store_oldPrice').present?            
            msrp = product_doc.at_css('#price span.atg_store_oldPrice span.amount').text.match(/([\d\.]+)/)[1]
          else            
            msrp = price
          end
          more_info = product_doc.xpath('//div[@id="productImage"]/ul').try(:children).try(:map, &:text) rescue []
          image_url = product_doc.xpath('//meta[@property="og:image"]/@content').text

          color_infos = []          

          product_sku = product_doc.xpath('//input[@id="pageLoadSku"]/@value').text
          item_import_key = "ivivva_#{product_sku}"
          
          color_info = {}
          
          swatch_tags = product_doc.xpath('//ul[@id="swatches"]/li/a')
          if swatch_tags.present?

            ordered_swatches = order_swatches(swatch_tags)            
            ordered_swatches.each_with_index do |swatch_tag, swatch_tag_index|
              color_info = {}
              if (swatch_tag_index > 0)
                b.execute_script('$("#carousel").html("");')
                b.a(id: swatch_tag['id']).click
                b.element(xpath: '//div[@id="carousel"]//img').wait_until_present
                product_doc = Nokogiri::HTML(b.html)
              end
              
              sizes_tags = product_doc.xpath('//ul[@id="sizes"]/li/a')
              color_info[:sizes] = []

              color_info[:color_item_url] = product_detail_url

              if sizes_tags.present?
                sizes_tags.each do |size_tag|
                  next if size_tag['class'].include?('soldOut')
                  color_info[:sizes] << size_tag['title'].strip
                end
              else
                color_info[:sizes] = ['One Size']
              end

              image_urls = product_doc.xpath('//div[@id="carousel"]//ul/li/a/img/@src').map(&:text)
              swatch_image_tags = swatch_tag.xpath('.//img')
              swatch_image_tags.each do |swatch_image_tag|
                next if swatch_image_tag['class'].include?('inactive')
                color_info[:image_url] = swatch_image_tag['src']
                break
              end
              
              
              color_info[:color] = swatch_tag['title'].strip
              

              color_id = swatch_tag['rev']
              color_info[:import_key] = "#{item_import_key}_#{color_id}"

              color_info[:images] = []          
              image_urls.each do |image_url|
                color_info[:images] <<  image_url.gsub("$pdp_thumb$", "")
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
            secondary_images: [],
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

      def order_swatches(swatch_tags)
        ordered_swatches = []
        color_ids = []
        if swatch_tags.count > 1
          selected_index = -1
          swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
            next unless swatch_tag['class'].include?('active')
            selected_index = swatch_tag_index
            ordered_swatches << swatch_tag
            color_ids << swatch_tag['rev']
            break          
          end
          
          swatch_tags.each_with_index do |swatch_tag, swatch_tag_index|
            next if selected_index == swatch_tag_index
            color_id = swatch_tag['rev']
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