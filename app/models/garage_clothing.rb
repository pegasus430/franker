class GarageClothing < Cj

  ADVERTISER_ID = 3173941

  class << self
    def store_items
      @store = Store.find_by(name: "Garage Clothing")
      create_items(@store, GarageClothing::ADVERTISER_ID)
    end
    
    #############################
    ######### More Info #########
    #############################
    def has_more_info
      true
    end
    
    def scrape_more_info(item_import_key, product_cj_obj, product_code, item_url)
      colors_info = []
      description = ''

      item_url = URI.decode(product_cj_obj.buy_url.split("url=").second)
      item_url = item_url.split("&cjsku=").first

      begin
        b = Watir::Browser.new(:phantomjs)
        b.goto item_url
        item_doc = Nokogiri::HTML(b.html)
      rescue Exception => e
        puts "^" * 40
        puts "Error opening item url: #{item_url}"
        puts "Error: #{e}"
        puts "^" * 40
      end

      description = product_cj_obj.description
      if item_doc.present?
        if item_doc.at_css('#descTab0Content')
          item_doc.css('#prodDetailSwatch div').each do |swatch|
            begin
              swatch_child = swatch.children.to_html
              cbody = Nokogiri::HTML(swatch_child)
              color_image_url = cbody.xpath('//@src').map(&:value)
              color_image_url = 'http:'+color_image_url[0]
              color_name = cbody.xpath('//@title').map(&:value)
              color_name = color_name[0]
              import_key = "#{item_import_key}_#{color_name.gsub(' ', '')}"
              color_item_url = item_url

              # get sizes of a color
              uri = URI.parse("http://www.garageclothing.com/us/prod/include/productSizes.jsp")

              http = Net::HTTP.new(uri.host, uri.port)
              request = Net::HTTP::Post.new(uri.request_uri)
              request.set_form_data({"colour" => swatch.attr('colourid'), "originalStyle" => "", "productId" => product_cj_obj.manufacturer_sku})
              response = http.request(request)
              item_sizes = response.body
              item_sizes = Nokogiri::HTML(response.body)

              sizes_array = []
              stockLevel = 0
              item_sizes.css('span').each do |s|
                if !s.attr('stockLevel').nil?
                  stockLevel = s.attr('stockLevel').to_i
                else
                  stockLevel = s.attr('stocklevel').to_i
                end

                if stockLevel > 0
                  sizes_array << s.attr('size')
                end
              end

              # get images of a color
              uri = URI.parse("http://www.garageclothing.com/us/prod/include/pdpImageDisplay.jsp")

              http = Net::HTTP.new(uri.host, uri.port)
              request = Net::HTTP::Post.new(uri.request_uri)
              request.set_form_data({"colour" => swatch.attr('colourid'), "originalStyle" => "", "productId" => product_cj_obj.manufacturer_sku})
              response = http.request(request)
              item_images = response.body
              item_images = Nokogiri::HTML(response.body)

              images_array = []
              item_images.css('#additionalViewsPDP ul li a').each do |s|
                images_array << 'http://'+s.attr('href')
              end

              colors_info << { image_url: color_image_url,
                               color: color_name,
                               sizes: sizes_array,
                               color_item_url: color_item_url,
                               images: images_array,
                               import_key: import_key }
            rescue Exception => e
              puts "^" * 40
              puts "ERROR: failed to parse color info for url: #{item_url}"
              puts "#{e.inspect}"
              puts "^" * 40
            end
          end
        end
      end
      close_browser(b)
      return {colors: colors_info, description: description, more_info: []}
    end

    def debug_import_key(store, product)
      if product.manufacturer_sku.present?
        return "#{store.name.downcase.split(' ').join('')}_#{product.manufacturer_sku}"
      end
    end
  end
end