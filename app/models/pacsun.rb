require "net/ftp"
class Pacsun < LinkShare

  ADVERTISER_ID = 39758
  CATEGORY_NAMES = ["Womens,Miscellaneous", "Womens,Legwear", "Womens,Jeans", "Womens,Dresses & Rompers", "Womens,Jewelry & Hair", "Womens,Tees", "Womens,Tops", "Womens,Shoes", "Womens,Skirts", "Womens,Pants", "Womens,Jackets", "Womens,Sweaters", "Womens,Belts & Hats", "Womens,Sunglasses", "Womens,Shirts & Flannels", "Womens,Long Sleeve Tees", "Womens,Shorts", "Womens,Hoodies & Fleece", "Womens,Tees", "Womens,Hoodies & Fleece", "Womens,Tanks & Camis", "Womens,Tanks & Camis", "Womens,Sweaters", "Womens,Skirts", "Womens,Backpacks", "Womens,Shorts", "Womens,Belts & Hats", "Womens,Legwear", "Womens,Pants", "Womens,Dresses & Rompers", "Womens,Shoes", "Womens,Swimwear", "Womens,Swimwear", "Womens,Fragrance", "Womens,Handbags", "Womens,Shirts & Flannels", "Womens,Jewelry & Hair", "Womens,Backpacks", "Womens,Tops", "Womens,Jeans", "Womens,Jackets"]

  class << self
    def store_items
      if File.exists?("db/data/pacsun.xml") && File.mtime("db/data/pacsun.xml").to_date == Date.today
        extract_xml("Pacsun")
      else
        gz_file = download_zip_files_via_ftp("Pacsun", Pacsun::ADVERTISER_ID)
        xml_file = unzip_gz_files("Pacsun") if gz_file
        extract_xml("Pacsun") if xml_file
      end
    end

    #############################
    ######### More Info #########
    #############################
    def has_more_info
      true
    end

    ##########################################################################
    # Get information for colors, sizes, description, additional description #
    ##########################################################################
    def scrape_more_info(item_url, import_key, product)
      @colors = []
      url = item_url.split("url%3D").second
      if url.nil?
        url = item_url
      end
      
      begin   
        item_doc = Nokogiri::HTML(get_html_content(url))
        description = item_doc.at_css(".description").try(:text).gsub(/\t/, '').gsub(/\n/, '')
        more_info = []
        more_info = item_doc.at_css(".description ul").try(:children).try(:map, &:text)
        @colors, @sizes = compile_product_details(item_doc, item_url, import_key)
        data = {colors_info: @colors, size: @sizes, description: description, more_info: more_info}
        data
      rescue Exception => e
        puts "^" * 40
        logger.info "URI parse error #{e}"
        puts "^" * 40
        data = {colors_info: [], size: [], description: '', more_info: []}
      end
    end

    ################################################
    # Scrap colors, sizes form detail product page #
    ################################################
    def compile_product_details(item_doc, item_url, item_import_key)
      @colors = []
      @sizes = []
  
      prod_detail = item_doc.at_css('#pdpMain').try(:text)
      colors_vals_contents_regex = /\{id: "colorCode", name: "Color",(.*\}\n\n\}\n\]\n\})/m
      sizes_vals_contents_regex = /\{id: "sizeCode", name: "Size",(.*)\n\n\}\n\]\n\}/m

      colors_vals_contents = colors_vals_contents_regex.match(prod_detail)[0]
      sizes_vals_contents = sizes_vals_contents_regex.match(prod_detail)[0]
      
      b = Watir::Browser.new(:phantomjs)
      b.goto item_url
      color_doc = Nokogiri::HTML(b.html)

      arr_colors = ExecJS.eval(colors_vals_contents)
      arr_colors['vals'].reverse.each do |av|
        color_sw_url = av['images']['swatch']['url']
        color = av['val']
        import_key = "#{item_import_key}_#{color}"
        
        begin
          if color_doc.css(".variationattributes .swatchesdisplay li").length > 1
            b.a(:title => color).when_present.click
          end
        rescue Exception => e
          ## Catch error like Net::ReadTimeout
          puts "^" * 40
          puts "color click exception #{e}"
          puts "^" * 40
        end
        color_doc = Nokogiri::HTML(b.html)
        sizes = []        
        color_doc.css(".productinfotop .variationattributes .swatches.size .swatchesdisplay li").each do |swatch|
          unless (!swatch.attr("style").nil?) || (swatch.attr("class").include? "unselectable") || swatch.attr("class") == "selected noswatch"
            sizes << swatch.css("a").attr("title").text
          end
        end
        @color = {image_url: color_sw_url,
                  color: color,
                  sizes: sizes,
                  color_item_url: item_url,
                  images: [],
                  import_key: import_key}
        
        if av['images']['large']          
          av['images']['large'].each do |img|
            @color[:images] << img['url']
          end
        elsif av['images']['medium']                     
          av['images']['medium'].each do |img|
            @color[:images] << img['url']            
          end          
        elsif av['images']['small']          
          av['images']['small'].each do |img|
            @color[:images] << img['url']
          end
        end
        @colors << @color
      end
      close_browser(b)
      return [@colors, @sizes]
    end

  end
end