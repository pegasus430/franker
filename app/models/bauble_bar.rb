class BaubleBar < StoreAPI
  class << self
    def store_items
      @store = Store.where(name: "Bauble Bar").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        Sidekiq.logger.info "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          @items = []
          main_doc = Nokogiri::HTML(open(category.url, 'User-Agent' => 'DoteBot'))
          @items << fetch_bb_data(main_doc)
          while main_doc.at_css('.pages .next').try(:attr, 'href').present? do
            url = main_doc.at_css('.pages .next').try(:attr, 'href')
            main_doc = Nokogiri::HTML(open(url, 'User-Agent' => 'DoteBot'))
            @items << fetch_bb_data(main_doc)
          end
          @items.flatten!
          create_items(@items, @store, category, created_at)
        end
      end
      
      complete_item_creation(@store)
    end

    def prices_for(item)
      product_id = item.at_css('.add-to-wishlist').attr("data-id")
      msrp = item.at_css("#old-price-#{product_id}").try(:at_css, ".price").try(:text).try(:strip) || item.at_css("#old-price-#{product_id}").try(:text).try(:strip) || ""
      price = item.at_css("#product-price-#{product_id}").try(:at_css, ".price").try(:text).try(:strip) 
      price ||= item.at_css("#product-price-#{product_id}").try(:text).try(:strip)
      price ||= item.at_css('.price').try(:text).try(:strip)
      price ||= ""

      {msrp: msrp, price: price}
    end

    def image_url_for(item)
      item.at_css('.product_link img').attr('data-srcset').split(",")[-1].split[0]
    end

    def url_for(item)
      item.at_css('.product-name > a').attr('href')
    end

    def name_for(item)
      item.css('.product-name > a').text
    end

    def fetch_bb_data(page_doc)
      data = []
      page_doc.css('.category-products .item').each do |item|
        # todo refactor
        next if item.text.strip.blank?
        prices = prices_for(item)
        name = name_for(item)
        image_url = image_url_for(item)
        import_key = "baublebar_#{image_url.gsub(/[^\d]/, "")}"
        url = url_for(item)
        data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item))
      end
      data
    end
  end
end
