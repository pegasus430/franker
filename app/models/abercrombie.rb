class Abercrombie < StoreAPI

  DOMAIN = "http://abercrombie.com/"

  class << self
    def store_items
      @store = Store.where(name: "Abercrombie").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|       
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          puts "Category URL : #{category.url}"
          begin
            main_doc = Nokogiri::HTML(open(category.url))
          rescue Exception => e
            puts "^" * 40
            puts "Error At Opening Category URL: #{category.url}"
            puts "Error: #{e}"
            puts "^" * 40
          end
          if main_doc.present?
            begin
              @items = fetch_abercrombie_page_data(Nokogiri::HTML(open(category.url)))
              @items.flatten!
            rescue Exception => e
              puts "^" * 40
              puts "Error At Items Fetching from URL: #{category.url}"
              puts "Error: #{e}"
              puts "^" * 40
            end
            create_items(@items, @store, category, created_at)
          end
        end
      end
      
      complete_item_creation(@store)
    end
    
    def has_more_info
      true
    end

    def get_prices(item)
      if item.at_css(".product-info .price .redline").present?
        price = item.at_css(".product-info .price .offer-price").text
        msrp = item.at_css(".product-info .price .redline .list-price").text
      else
        price = item.at_css(".product-info .price .offer-price").text
        msrp = ""
      end
      {price: price, msrp: msrp}
    end

    def fetch_abercrombie_page_data(page_doc)
      data = []
      name, url, price, msrp, image_url, import_key = ""
      page_doc.css(".category.products .product-wrap").each do |item|
        url = "http://www.abercrombie.com" + item.at_css(".image-wrap a")["href"]
        
        image_small = "http:" + item.at_css(".image-wrap a .prod-img")["data-src"]
        image_medium = image_small.gsub("$category-anf$", "$productMain-anf$")
        image_url = image_medium.present? ? image_medium : image_small
        name = item.at_css(".product-info .name a").text

        import_key = "abercrombie_#{item.at_css(".product-info .name a")["data-productid"]}"
        price_values = get_prices(item)
        unless price_values[:price] == "Sold Out"
          more_info_dict = get_more_infos(url, import_key)
          data << {name: name, url: url, price: price_values[:price], msrp: price_values[:msrp], image_url: image_url, import_key: import_key}.merge(more_info_dict)
        end        
      end
      data
    end

    def get_more_infos(product_url, item_import_key)
      b = Watir::Browser.new(:phantomjs)      
      b.goto product_url
      product_doc = Nokogiri::HTML(b.html)

      desc = product_doc.xpath('//h2[@class="copy"]').text
      more_info = []

      color_infos = []

      color_info = {}
      swatche_tags = product_doc.xpath('//div[@class="fullwidth-product"]//li[contains(@class, "swatch")]/a')
      unless swatche_tags.present?
       color_infos << get_color_info_for_one_color(product_doc, product_url, item_import_key)
      else
          begin
            if product_doc.css('.language-buttons').present?
              b.as(css: '.language-buttons a')[0].click
            end

            ## DO scrapping selected color 
            swatche_tags.each_with_index do |swatch_tag, swatch_tag_index|
              next unless swatch_tag.parent['class'].include?('selected')
              color_info = {}
              
              sizes_tags = product_doc.xpath('//select[@class="size-select"]/option')          
              color_info[:sizes] = []
              if sizes_tags.present?
                sizes_tags.each do |size_tag|          
                  next unless size_tag['data-size-name']
                  color_info[:sizes] << size_tag['data-size-name']
                end
              else
                color_info[:sizes] = ['One Size']
              end
              color_info[:color] = swatch_tag['title']
              color_info[:color_item_url] = product_url

              color_id = color_info[:color].split(' ').join('_').downcase

              color_info[:import_key] = "#{item_import_key}_#{color_id}"
              image_urls = product_doc.xpath('//div[contains(@class, "image-util")]/ul[@class="thumbnails"]/li/img/@src').map(&:text)
              
              color_info[:image_url] = image_urls[0]
              color_info[:image_url] = "http:#{color_info[:image_url]}" unless color_info[:image_url].include?('http')
              color_info[:image_url] = color_info[:image_url].gsub(/\?.*/, "?$productThumbnailOFP-anf$")

              color_info[:images] = []
              image_urls.each do |image_url|                    
                color_info[:images] <<  "http:" + image_url.gsub(/\?.*/, "")
              end          
              color_infos << color_info
            end

            ## DO scrapping unselelected colors
            swatche_tags.each_with_index do |swatch_tag, swatch_tag_index|
              next if swatch_tag.parent['class'].include?('selected')
              color_info = {}

              b.execute_script("$('ul.thumbnails').html('');")
              b.a({href: swatch_tag['href'], class: 'swatch-link'}).click
              b.element(:xpath => "//ul[@class='thumbnails']/li").wait_until_present
              product_doc = Nokogiri::HTML(b.html)

              sizes_tags = product_doc.xpath('//select[@class="size-select"]/option')          
              color_info[:sizes] = []
              if sizes_tags.present?
                sizes_tags.each do |size_tag|          
                  next unless size_tag['data-size-name']
                  color_info[:sizes] << size_tag['data-size-name']
                end
              else
                color_info[:sizes] = ['One Size']
              end
              color_info[:color] = swatch_tag['title']
              color_info[:color_item_url] = product_url

              color_id = color_info[:color].split(' ').join('_').downcase

              color_info[:import_key] = "#{item_import_key}_#{color_id}"
              image_urls = product_doc.xpath('//div[contains(@class, "image-util")]/ul[@class="thumbnails"]/li/img/@src').map(&:text)
              color_info[:images] = []

              
              color_info[:image_url] = image_urls[0]
              color_info[:image_url] = "http:#{color_info[:image_url]}" unless color_info[:image_url].include?('http')
              color_info[:image_url] = color_info[:image_url].gsub(/\?.*/, "?$productThumbnailOFP-anf$")

              image_urls.each do |image_url|                    
                color_info[:images] <<  "http:" + image_url.gsub(/\?.*/, "")
              end          
              color_infos << color_info
            end



          rescue Exception => e
            puts '^'*20
            puts "Encounted error #{e} while scraping secondary images on AmericanEagle scraper"
            puts '-'*20
          end
      end
      
      all_sizes = []
      color_infos.each do |color_info|
        all_sizes << color_info[:sizes]
      end

      close_browser(b)

      return { colors: color_infos, description: desc, size: all_sizes.flatten.compact.uniq, more_info: more_info }
    end

    def get_color_info_for_one_color(product_doc, item_url, item_import_key)
      color_info = {}
      main_img_url = product_doc.css('img.prod-img').attr('src')
      
      if main_img_url.kind_of?(Array)
        color_info[:image_url] = main_img_url[0].try(:text) if main_img_url.kind_of?(Array)
      else
        color_info[:image_url] = main_img_url.try(:text)
      end
      
      color_info[:image_url] = color_info[:image_url].gsub(/\?.*/, "?$productThumbnailOFP-anf$")
      unless color_info[:image_url].include?('http')
        color_info[:image_url] = "http:#{color_info[:image_url]}"
      end
      sizes_tags = product_doc.xpath('//select[@class="size-select"]/option')          
      color_info[:sizes] = []
      if sizes_tags.present?
        sizes_tags.each do |size_tag|          
          next unless size_tag['data-size-name']
          color_info[:sizes] << size_tag['data-size-name']
        end
      else
        color_info[:sizes] = ['One Size']
      end
      color_info[:color] = product_doc.at_css('li.color span.color').try(:text)
      color_info[:color_item_url] = item_url        
      color_id = color_info[:color].split(' ').join('_').downcase
      color_info[:import_key] = "#{item_import_key}_#{color_id}"
      image_urls = product_doc.xpath('//div[contains(@class, "image-util")]/ul[@class="thumbnails"]/li/img/@src').map(&:text)
      color_info[:images] = []          
      image_urls.each do |image_url|                    
        color_info[:images] <<  "http:" + image_url.gsub(/\?.*/, "")
      end

      color_info
    end

    private
    def get_rid_quotes(str)
      str[0] = '' if str[0] == "'"
      str[-1] = '' if str[-1] == "'"
      str
    end

  end
end