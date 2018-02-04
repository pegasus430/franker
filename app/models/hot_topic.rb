class HotTopic < StoreAPI
  API_URL = 'http://www.hottopic.com/hottopic/htStore/ajax/getProducts.jsp?sortByFieldId=8&sortByDir=descending&filterQuery=&folderId=%%folderId%%&page=%%page%%&productsPerPage=%%products_per_page%%&userClicked=false'
  REG_EX = /.*?var\scurrentFolderId\s=\s'(.*)';?/i
  class << self
    def store_items
      @store = Store.where(name: "Hot Topic").last
      @categories = @store.categories.external
      created_at = DateTime.now
      @categories.each do |category|     
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          Sidekiq.logger.info "Category URL : #{category.url}"
          @items = []
          page = Curl.get(category.url).body
          if page =~ REG_EX
            folderId = page.match(REG_EX)[1]
            url = API_URL.gsub("%%products_per_page%%", "1000").gsub("%%folderId%%", folderId)
            url = url.gsub("%%page%%", "1")
            json = JSON.parse(Curl.get(url).body)
            json_items = json["ROW_ARRAY"]
            remaining_items = json["product_count"].to_i - json_items.size
            if remaining_items > 0
              url = API_URL.gsub("%%products_per_page%%", "1000").gsub("%%folderId%%", folderId)
              url = url.gsub("%%page%%", "2")
              json_items << JSON.parse(Curl.get(url).body)["ROW_ARRAY"]
              json_items.flatten!
            end
            @items = store_ht_items(json_items)
          end
          @items.flatten!
          create_items(@items, @store, category, created_at)
        end        
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      { msrp: item["origPrice"] || "", price: item["stdPrice"]}
    end

    def image_url_for(item)
      "#{item["scene7ImgURL"]}?wid=1080"
    end

    def url_for(item)
      "http://www.hottopic.com#{item["url"]}"
    end

    def name_for(item)
      item["webTitle"]
    end

    def out_of_stock?(item)
      url = url_for(item)
      main_doc = Nokogiri::HTML(open(url, 'User-Agent' => 'DoteBot'))
      html_s = main_doc.to_s.encode!('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
      html_s.gsub!(/\n+|\s+/, "")
      if html_s =~ /.*jsonProdSkus=(.*[^;])?;vars7RootURL.*/i
        JSON.parse(html_s.match(/.*jsonProdSkus=(.*[^;])?;vars7RootURL.*/i)[1]).size <= 0
      else
        true
      end
    end

    def store_ht_items(json_items)
      data = []
      json_items.each do |item|
        # todo refactor
        unless out_of_stock?(item)
          name = CGI::unescapeHTML(name_for(item))
          image_url = image_url_for(item)
          import_key = "hottopic_#{item["prdId"]}_#{item["prdCode"]}"
          url = url_for(item)
          color_infos = get_more_infos(url, import_key)
          data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item)).merge(color_infos)
        end        
      end
      data
    end

    def has_more_info
      true
    end
    
    def get_more_infos(product_url, item_import_key)
      desc = ''
      more_info = []
      color_infos = []
      begin
        b = Watir::Browser.new(:phantomjs)      
        b.goto product_url
        product_doc = Nokogiri::HTML(b.html)

        desc = product_doc.xpath('//article[@id="productDesc"]/p').text.strip
        more_info = product_doc.xpath('//article[@id="productDesc"]/ul').try(:children).try(:map, &:text)

        color_info = {}
        sizes_tags = product_doc.xpath('//select[@id="selProdSize"]/option')
        color_info[:sizes] = []
        
        sizes_tags.each do |size_tag|
          next unless size_tag['value'].present?
          color_info[:sizes] << size_tag.text.strip
        end
        unless sizes_tags.present?
          color_info[:sizes] << "One Size"
        end

        color_info[:color] = 'One Color'
        color_info[:color_item_url] = product_url

        color_id = 'one_color'

        color_info[:import_key] = "#{item_import_key}_#{color_id}"

        image_tags = product_doc.xpath('//li[@class="alternates"]/a/img')          
        image_urls = []
        image_tags.each do |image_tag|
          next unless image_tag.parent['class'] == 'alt'
          image_urls << image_tag['src']
        end          
        color_info[:image_url] = image_urls[0]

        color_info[:images] = []
        image_urls.each do |image_url|                    
          color_info[:images] << image_url.gsub("newht_product_tn$", "newht_product_lg$")
        end
                 
        color_infos << color_info
        
      rescue Exception => e
        puts '^' * 40
        puts "Encounted error while scraping item info on HotTopic: #{product_url}"
        puts "Error: #{e}"
        puts '^' * 40
      end
      
      all_sizes = []
      color_infos.each do |color_info|
        all_sizes << color_info[:sizes]
      end

      close_browser(b)

      return { colors: color_infos, description: desc, size: all_sizes.flatten.compact.uniq, more_info: more_info }
    end

  end
end