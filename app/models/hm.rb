class HM < StoreAPI
  IMAGE_REGEX = /(.*?file:\/product\/)(.*)(\])/i
  SUBCATEGORY_REGEX = /.*?\?(Nr=\d+?#)(.*)/i
  MORE_INFO_TEMPLATE = "%%shortInformation%% Imported Art.No. %%catalogActivityArticleNumber%%"
  class << self
    def store_items
      @store = Store.where(name: "H&M").last
      @categories = @store.categories.external.non_sale + @store.categories.external.sale
      created_at = DateTime.now

      @categories.reverse.each do |category|
        Sidekiq.logger.info "Category URL : #{category.url}"
        unless category.url == "NA" || category.url.nil? || category.url.empty?
          begin
            if category.url =~ HM::SUBCATEGORY_REGEX
              uri = URI.parse(category.url)
              new_url = "#{uri.scheme}://#{uri.host}#{uri.path}?#{category.url.match(HM::SUBCATEGORY_REGEX)[2]}"
              main_doc = Nokogiri::HTML(open(new_url, "User-Agent" => "DoteBot"))
            else
              main_doc = Nokogiri::HTML(open(category.url, "User-Agent" => "DoteBot"))
            end
          rescue Exception => e
            Sidekiq.logger.info "^" * 40
            Sidekiq.logger.info "Error: #{e}"
            Sidekiq.logger.info "Error At Opening Category URL: #{category.url}"
            Sidekiq.logger.info "^" * 40
          end
          if main_doc.present?
            @items = []
            store_page_no_url = category.url
            begin
              @items << fetch_hm_data(main_doc, category.url)
              @items.flatten!
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

    def fetch_hm_data(page_doc, url)
      data = []
      uri = URI.parse(url)
      page_doc = page_doc.dup
      while true do
        next_path = page_doc.at_css('ul.pages.bottom li.next > a').try(:attr, 'href')
        page_doc.css("#list-products > li").each do |item|
          name = item.at_css('.details').text.strip
          price = if item.at_css('.price .new').present?
            item.at_css('.price .new').text.strip
          else
            item.at_css('.price span').text.gsub(/\s+|\r+|\n+/i, "")
          end
          msrp = item.at_css('.price .old').present? ? item.at_css('.price .old').text.strip : ""
          item_url = item.at_css('div > a').attr('href')
          begin
            unless item_url.nil? && URI.parse(item_url).query.nil?
              import_key = URI.parse(item_url).query.parameterize
            end
          rescue Exception => e
            Airbrake.notify_or_ignore(
              e,
              parameters: {item_url: item_url, url: url, item_data: item},
              cgi_data: ENV.to_hash
            )
            next
          end
          thumb_image_url = item.css('.image').search('img[data-imgtype=FASHION_FRONT]')[0].attr('src') rescue nil
          thumb_image_url ||= item.css('.image').search('img')[0].attr('src')
          image_url =  thumb_image_url.gsub(IMAGE_REGEX, 'http:\1full\3')
          data << { name: name, url: item_url, price: price, msrp: msrp, image_url: image_url , import_key: import_key }
        end
        if next_path.present?
          next_page_url = "#{uri.scheme}://#{uri.host}#{uri.path}#{next_path}"
          page_doc = Nokogiri::HTML(open(next_page_url, "User-Agent" => "DoteBot"))
          break if page_doc.blank?
        else
          break
        end
      end
      with_color_and_more_info(data)
    end

    def with_color_and_more_info(data)
      data = data.inject([]){ |all_data, item|
        all_data ||= []
        code = item[:url].gsub(/http:\/\/www.hm.com\/us\/product\/(\d+)\?.*/i, '\1')
        item.merge!(import_key: code)
        all_data << item
        all_data
      }
      grouped_name = data.group_by{|item| item[:import_key]}
      grouped_name.keys.inject([]) { |result, value|
        result ||= []
        colors_info = []
        single_item_hash = grouped_name[value][0].with_indifferent_access
        begin
          json_page_data = product_json_from(single_item_hash["url"]).dup
        rescue Exception => e
          Sidekiq.logger.info "^" * 40
          Sidekiq.logger.info "with_color_and_more_info exception raised for URL : #{single_item_hash["url"]}"
          Sidekiq.logger.info e.message
          Sidekiq.logger.info "^" * 40
          next
        end
        articles = json_page_data["articles"]
        description = json_page_data["description"]
        more_info_hash = articles[articles.keys.first]
        more_info = [more_info_hash["shortInformation"], more_info_hash["catalogActivityArticleNumber"]].compact
        all_sizes = []
        article_hash = {}
        colors_info << articles.keys.flat_map { |article_key|
          article_hash = articles[article_key]
          unless article_hash["soldOut"]
            variants = article_hash["variants"]
            colors_hash = { import_key: article_hash["code"],
              color_item_url: article_hash["share"]["pageUrl"],
              images: article_hash["images"].map{ |image| "http://lp.hm.com/hmprod?set=#{image["zoomAreaParams"]}&call=url[file:/product/full]" },
              sizes: variants.keys.inject([]){ |sizes, variant_key|
                variant_size = variants[variant_key]
                sizes ||= []
                sizes << variant_size["size"]["name"] unless variant_size["soldOut"]
                all_sizes << variant_size["size"]["name"]
                sizes
              },
              color: article_hash["description"]
            }
            colors_hash
          end
        }.compact
        single_item_hash.merge!({
          import_key: "hm_#{json_page_data["code"]}",
          colors: colors_info.flatten.compact,
          size: all_sizes.compact.uniq.flatten.reject { |c| c if c.gsub(" ", "").empty? } || [],
          description: description,
          more_info: more_info
        })

        result << single_item_hash
        result
      }
    end

    def product_json_from(url)
      page_data = Curl.get(url).body
      page_data = page_data.gsub(/\r\n/m, "\n").gsub(/\s+/, " ")
      regex = /.*<script type="text\/javascript">\shm.data.product\s=\s(.*})?\s*<\/script>.*/i
      json_data = JSON.parse(page_data.match(regex)[1])
    end
    
    def has_more_info
      true
    end
  end
end
