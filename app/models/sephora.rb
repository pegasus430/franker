require "net/ftp"
class Sephora < LinkShare

  ADVERTISER_ID = "2417"

  class << self
    def store_items
      name = "Sephora"
      if File.exists?("db/data/#{name.downcase}.xml") && File.mtime("db/data/#{name.downcase}.xml").to_date == Date.today
        extract_xml(name)
      else
        gz_file = download_zip_files_via_ftp(name, ADVERTISER_ID)
        xml_file = unzip_gz_files(name) if gz_file
        extract_xml(name) if xml_file
      end
    end

    def has_more_info
      true
    end

    def get_import_key(product, store_name)
      item_url = product.at_css("URL product").text
      item_url = URI.decode(item_url)
      item_url = item_url.split('?SKUID').first
      item_unique_id = item_url.split('-').last

      item_unique_id
    end

    def scrape_more_info(item_url, item_import_key, product)
      colors_info = []
      description = ''

      if product.at_css("description long")
        description = product.at_css("description long").text
      end

      begin
        b = Watir::Browser.new(:phantomjs)
        b.goto item_url
        Watir::Wait.until { b.text.include? 'Sephora' }
        item_doc = Nokogiri::HTML(b.html)
      rescue Exception => e
        puts "^" * 40
        puts "Error opening item url: #{item_url}"
        puts "Error: #{e}"
        puts "^" * 40
      end

      if item_doc.present?
        if item_doc.at_css('.SwatchGroup-selector')
          item_doc.css('.SwatchGroup-selector div').each do |swatch|
            if swatch.attr('data-analytics').present? && swatch.attr('data-at').present?
              begin
                color_name = swatch.attr('data-analytics')
                color_name = color_name.split(":").last
                color_code = swatch.attr('data-at')
                color_code = color_code.split("_").last
                import_key = "#{item_import_key}_#{color_code}"
                color_item_url = item_url

                images_array = []
                item_doc.css("#sku1466648-thumbs .SwatchGroup-selector div .Swatch-img").each do |thumbnail|
                  image_url = 'http://www.sephora.com' + thumbnail.attr("src")
                  image_url = image_url.gsub('-thumb-50.jpg' , '-hero-300.jpg').gsub('-thumb50.jpg', '-hero-300.jpg')
                  images_array << image_url
                end
                
                if images_array.count == 0
                  swatch_child = swatch.children.to_html
                  cbody = Nokogiri::HTML(swatch_child)
                  color_image_url = cbody.xpath('//@src').map(&:value)
                  color_image_url = 'http://www.sephora.com'+color_image_url[0]
                  images_array << color_image_url.split("+sw").first+'-main-hero-300.jpg'
                end

                colors_info << { image_url: color_image_url,
                                 color: color_name,
                                 sizes: ["One Size"],
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
      end
      close_browser(b)
      return {colors_info: colors_info, description: description, more_info: []}
    end
  end
end