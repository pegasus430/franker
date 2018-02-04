class Wildfox < StoreAPI
  class << self
    REGEX = /.*currentCategoryId=(\d*)?;.*pages=(\d*);/i
    CATEGORY_URL = "http://www.wildfox.com/catalog/category/ajax/?id=%%category_id%%&p=%%page%%&limit=18&dir=asc&order=position"
    def store_items
      @store = Store.find_by(name: "Wildfox")
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          @items = []
          main_docs_s = Curl.get(category.url).body
          main_docs_s.gsub!(/\n+|\s+/, "")
          if main_docs_s =~ REGEX
            category_id = main_docs_s.match(REGEX)[1]
            pages = main_docs_s.match(REGEX)[2].to_i
            @items = []
            current_page = 1
            while current_page <= pages do
              url = CATEGORY_URL.gsub("%%category_id%%", category_id).gsub("%%page%%", "#{current_page}")
              @items << fetch_wf_data(Nokogiri::HTML(open(url, 'User-Agent' => 'DoteBot')))
              current_page = current_page + 1
            end
          end
          @items.flatten!
          create_items(@items, @store, category, created_at)
        end
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      if item.at_css(".special-price > .price").try(:text).present? && item.at_css('.old-price > .price').try(:text).present?
        price = item.at_css(".special-price > .price").try(:text).try(:strip)
        msrp = item.at_css(".old-price > .price").try(:text).try(:strip)
      else
        msrp = ""
        price = item.at_css(".regular-price > .price").try(:text).try(:strip)
      end
      { msrp: msrp, price: price}
    end

    def image_url_for(item)
      item.at_css('a > img').attr('src')
    end

    def url_for(item)
      item.at_css('> a').attr('href')
    end

    def name_for(item)
      item.css('.product-name > a').text.strip
    end

    def fetch_wf_data(page_doc)
      data = []
      page_doc.css('.item').each do |item|
        next if item.attr('class').split(" ").map(&:downcase).include?("promo")
        name = name_for(item)
        image_url = image_url_for(item)
        import_key = "wildfox_#{item.at_css('>a').attr('id')}"
        url = url_for(item)
        data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item))
      end
      data
    end
  end
end