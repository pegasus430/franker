require "net/ftp"
class Topshop < LinkShare

  ADVERTISER_ID = 35861
  CATEGORY_NAMES = ["Accessories", "Apple iPad Accessories", "Backpacks", "Bags & Cases",
    "Books Other", "Christmas Gifts", "Clutch Bag", "Cosmetic Bags", "Cross Body Bag", "Girls Dresses",
    "Hair Accessories", "Handbags & Luggage", "Headboards", "Jumpsuit", "Knitwear", "Laptop Bags",
    "Lingerie/Underwear", "Luggage", "Miscellaneous Handbags & Luggage", "Miscellaneous Jewellery",
    "Nightwear", "Other Gifts", "Other Office Equipment", "Playsuit", "Satchel", "Shoes Other",
    "Shoulder Bag", "Trousers", "Unisex belts", "Wallets", "Women's Leggings", "Womens 3/4 Length Trousers",
    "Womens Accessories Other", "Womens Anklets", "Womens belts", "Womens bikinis", "Womens blouses",
    "Womens Boots", "Womens Bracelets", "Womens bras", "Womens Brooches & Pins",
    "Womens Camisoles and Sleepwear", "Womens Cardigans", "Womens Clothing other", "Womens coats",
    "Womens dresses", "Womens Earrings", "Womens Fragrance Gift Packs", "Womens gowns",
    "Womens Hair Accessories", "Womens hats", "Womens High Heels", "Womens jackets", "Womens jeans",
    "Womens Jewellery Sets", "Womens Jumpers", "Womens leisure bags", "Womens Necklaces",
    "Womens Other Jewellery", "Womens pyjamas", "Womens Rings", "Womens Sandals", "Womens scarves",
    "Womens shirts", "Womens Shoes", "Womens shorts", "Womens skirts", "Womens Slippers", "Womens socks",
    "Womens sunglasses", "Womens sweaters", "Womens t-shirts and vests", "Womens thongs and g-strings",
    "Womens Tops", "Womens umbrellas"]

  class << self
    def store_items
      if File.exists?("db/data/topshop.xml") && File.mtime("db/data/topshop.xml").to_date == Date.today
        extract_xml("Topshop")
      else
        gz_file = download_zip_files_via_ftp("Topshop", Topshop::ADVERTISER_ID)
        xml_file = unzip_gz_files("Topshop") if gz_file
        extract_xml("Topshop") if xml_file
      end
    end

    #############################
    ######### More Info #########
    #############################
    def has_more_info
      true
    end
    
    def scrape_more_info(item_url, import_key, product)
      colors = []
      url = item_url.split("url%3D").second
      if url.nil?
        url = item_url
      end
      
      begin
        item_doc = Nokogiri::HTML(get_html_content(url))
        
        description = item_doc.at_css(".product_description").try(:text).try(:strip)
        more_info = []
        more_info = item_doc.at_css("#product_tab_1 .product_summary").try(:children).try(:map, &:text)
        image_url = product.at_css("URL productImage").text

        thumbs_regex = /thumbnails: \[([\"_\d,]+)\]/
        size_regex = /\{size: \"([\dLSMX]+)\", sku:/
        product_detail = item_doc.css('#wrapper_content').try(:text)
        if product_detail
          matches = thumbs_regex.match(product_detail)
        end
        if matches && matches[1]
          thumbs_ids = matches[1].gsub('"', '').split(",")
        end
        
        sizes = []
        item_doc.css("#product_size_full option").each do |size_option|
          size = size_option.attr("value")
          disabled = size_option.attr("disabled")
          if size.present? && (!disabled.present? || disabled != "disabled")
            if size == "ONE"
              size = "One Size"
            end
            sizes << size
          end
        end

        if thumbs_ids
          secondary_images = thumbs_ids.collect { |thumb_id| image_url.gsub('_normal.jpg', (thumb_id=='_' ? '':thumb_id)+'_large.jpg') }
        else
          secondary_images = []
        end
        
        color = item_doc.at_css("#product_tab_1 .product_summary .product_colour span").try(:text)
        unless color
          color = "One Color"
        end
        
        colors << {image_url: image_url,
                   color: color,
                   sizes: sizes,
                   color_item_url: item_url,
                   images: secondary_images,
                   import_key: import_key}

        {colors_info: colors, size: sizes, description: description, more_info: more_info, secondary_images: secondary_images}      
      rescue Exception => e
        puts "^" * 40
        puts "Error #{e}"
        data = {colors_info: [], size: sizes, description: '', more_info: '', secondary_images: []}
        puts "^" * 40
      end
    end

  end
end