class Pink < StoreAPI
  DOMAIN  = "https://www.victoriassecret.com"
  class << self
    def store_name
      "Pink"
    end

    def store_items
      @store = Store.where(name: store_name).last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now
      @categories.each do |category|
        Sidekiq.logger.info "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          begin
            main_doc = Nokogiri::HTML(open(category.url.try(:strip), 'User-Agent' => 'firefox'))
          rescue Exception => e
            Sidekiq.logger.info "^" * 40
            Sidekiq.logger.info "Error At Opening Category URL: #{category.url}"
            Sidekiq.logger.info "Error: #{e}"
            Sidekiq.logger.info "^" * 40
          end
          if main_doc.present?
            @items = []
            store_page_no_url = category.url
            Sidekiq.logger.info "#" * 50
            begin
              @items << fetch_pink_data(main_doc)
              @items.flatten!
              while !last_page?(main_doc) do
                new_url = "#{category.url.try(:strip)}/more?increment=180&location=#{@items.count+1}&sortby=REC"
                main_doc = Nokogiri::HTML(open(new_url, 'User-Agent' => 'firefox'))
                @items << fetch_pink_data(main_doc)
                @items.flatten!
              end
            rescue Exception => e
              Sidekiq.logger.info "^" * 40
              Sidekiq.logger.info "Error At Items Fetching for URL: #{store_page_no_url}"
              Sidekiq.logger.info "Error: #{e}"
              Sidekiq.logger.info "Message:\n #{e.message}"
              Sidekiq.logger.info "backtrace:\n #{e.backtrace.join('\n')}"
              Sidekiq.logger.info "^" * 40
              Airbrake.notify_or_ignore(
                e,
                parameters: {},
                cgi_data: ENV.to_hash
              )
            end
            create_items(@items, @store, category, created_at)
          end
        end
      end
      complete_item_creation(@store)
    end

    def prices_for(item)
      begin
        price_item = item.at_css(' > a > p')
        price_item ||= item.at_css(' > a > aside > p')
        msrp = price_item.at_css(' > del').try(:text).try(:strip) || ""
        price = price_item.at_css(' > em').try(:text).try(:strip) || price_item.text.strip
        if price =~ /any\s\d+.*/i
          item_text = price_item.text.strip
          price = item_text.split("or")[0].strip
          if price =~ /\$\d+(.\d+)?\s*&/i
            # $58 & $14.50
            price = price.split('&')[0].strip
          end
          price
        # $28 & $72 - $75 & $25
        elsif price =~ /(\$\d+)\s&\s\$\d+?.*/i
          price = price.match(/(\$\d+)\s&\s\$\d+?.*/i)[1].strip
        end
        { price: price, msrp: msrp }
      rescue Exception => e
        Airbrake.notify_or_ignore(
          e,
          parameters: {item: item},
          cgi_data: ENV.to_hash
        )
      end
    end

    def image_url_for(item)
      image_src = item.search('meta[itemprop=image]')[0].attr('content')
      image_src.gsub!("224x299", "760x1013")
      "http:#{image_src}"
    end

    def fetch_pink_data(page_doc)
      data = []
      page_doc.css('li[itemtype="http://schema.org/Product"]').each do |item|
        name = item.at_css('hgroup h3').text.strip
        url = "#{DOMAIN}#{item.at_css('> a').attr('data-product-path')}"
        image_url = image_url_for(item)
        import_key = "#{store_name.downcase}_#{item.at_css('> a').attr('data-product-id')}_#{item.at_css('> a').attr('data-category-id').parameterize}"
        data << { name: name, import_key: import_key, image_url: image_url, url: url }.merge(prices_for(item))
      end
      data
    end

    def import_item?(item)
      item_type = item.attr('itemtype')
      item_type == "http://schema.org/Product"
    end

    def last_page?(main_doc)
      main_doc.css('li[itemtype="http://schema.org/Product"][class="last"]')[0].present?
    end
  end
end
