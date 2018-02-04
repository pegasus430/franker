class UrbanOutfitters < Cj

  ADVERTISER_ID = 3929100
  CATEGORY_NAMES = ["W_SHOES_SNEAKERS", "W_APP_TEES", "SALE_W_SHOES", "WOMENS_SHOES", "W_APP_SWEATERTANKS",
    "W_SHOES_BOOTS", "W_INTIMATES", "W_OUTERWEAR", "W_APP_SWEATERS", "W_APP_SHORTS_SHORTS",
    "W_SHOES_HEELSWEDGES", "W_APP_DRESSES", "W_APP_JEANS", "W_TOPS", "W_ACC_BAGS", "W_INTIMATES_SLIPSANDSLEEP",
    "W_APP_CAMIS", "W_APP_BOTTOMS_SHORTS", "W_APP_TEES_GRAPHIC", "W_APP_BLOUSES", "W-BAGSBELTS-BAGS",
    "W_ACC_BRACELETS", "W_SHOES_OXFORDSLOAFERS", "W_BOTTOMS", "W_APP_BRAS", "W_ACC_SUNGLASSES",
    "BEAUTY_MAKEUP_LIPS", "BEAUTY_MAKEUP", "W_ACC_HAIRACCESSORIES", "BEAUTY_BODY_SCRUBS", "W_LOUNGE_BODYSUITS",
    "WOMENS_ACCESSORIES", "BEAUTY_MAKEUP_EYES", "BEAUTY_MAKEUP_FACE", "BEAUTY_HAIRSKIN", "W_ACC_JEWELRY",
    "W_APP_VINTAGEBOTTOMS", "W_SHOES_ALLSHOES_SANDALS", "W_ACC_NECKLACE", "B_HAIR_WASH", "B_HAIR_STYLE",
    "W_APP_BLOUSES_SOLID", "W_SHOES_FLATS", "BEAUTY_BODY_SUN", "W_OUTERWEAR_JACKETS", "BEAUTY_SKIN_TONER",
    "BEAUTY_SKIN_MASKS", "BEAUTY_NAILS_POLISH", "W_INTIMATES_UNDERWEAR", "W_BEAUTY_SKIN", "W_APP_BLOUSES_BTTNUP",
    "W_LOUNGE", "W_APP_SWIMWEAR_ONE", "BEAUTY_SKIN_CLEANSER", "BEAUTY_HAIR_TREAT", "W_APP_VINTAGETOPS", "B_SKIN_BODY_LOTION",
    "W_ACC_HATS", "W_BEAUTY", "W_ACC_SCARVES", "W_APP_HOODIES", "W_BEAUTY_SCENT", "W_APP_SHORTS_SKIRTS",
    "W_APP_VINTAGEACC", "W_ACC_BELTS", "W_APP_SWIMWEAR", "W_BEAUTY_NAIL", "W_SWIM_MIXMATCH",
    "W_ACC_TIGHTS_LEGGINGS", "W_ACC_JEWELRY_RINGS", "W_APP_SWEATERS_PULLOVERS", "W_ACC_EARRINGS", "W_APP_PANTS",
    "W_OUTERWEAR_BLAZERS", "W_APP_SWEATERS_PULLOVER", "W_VINTAGEDRESS", "W_APP_BLOUSES_CMSANDTNKS", "W-SKIRTS-MAXI", "W_ACC_WALLET", "W_ACC_BODYJEWELRY", "W_SWIM_COVERUPS", "W_ACC_LEGGINGSANDTIGHTS",
    "W_OUTERWEAR_COATS", "W-ACC-HATS-SUNGLASSES", "W_APP_VINTAGEJACKETS", "BEAUTY_SKIN_SUN", "W_APP_CARDIGANS"]


  class << self
    def store_items
      @store = Store.find_by(name: "Urban Outfitters")
      create_items(@store, UrbanOutfitters::ADVERTISER_ID, UrbanOutfitters::CATEGORY_NAMES)
    end
    
    def debug_import_key(store, product)
      "#{store.name.downcase.split(' ').join('')}_#{product.image_url.split('/')[-1].split("?")[0].split("_")[0]}"
    end
    
    #############################
    ######### More Info #########
    #############################
    def has_more_info
      true
    end
    
    def scrape_more_info(item_import_key, product_cj_obj, product_code, item_url)
      colors_info = []
      api_url = "http://www.urbanoutfitters.com/api/v1/product/" + product_code
      item_json_data = JSON.parse(Curl.get(api_url).body)
      product = item_json_data["product"]

      product_price_info = product["skusInfo"].first["priceLists"].last
      price = 0, msrp = 0
      if product_price_info["currencyCode"] == "USD"
        if product_price_info["salePrice"].present?
          price = product_price_info["salePrice"]
          msrp = product_price_info["listPrice"]
        else
          price = product_price_info["listPrice"]
          msrp = 0
        end
        price = (price *100).to_i
        msrp = (msrp *100).to_i
      end

      description = ActionView::Base.full_sanitizer.sanitize(product["longDescription"]).gsub("&nbsp;", "")
      desc = description.split("\n")[1] || description.split("Content + Care")[1] || description.split("CONTENT + CARE")[1]
      more_info = desc.present? ? desc.split("-").map {|i| i if i.gsub(" ", "").length > 0 }.compact : nil
      base_url = "http://images.urbanoutfitters.com/is/image/UrbanOutfitters/"
      swatch_url = "http://www.urbanoutfitters.com/urban/images/swatches/"
      product["colors"].each do |color|
        color_image_url = swatch_url + "#{color['id']}_s.png"
        item_images = color["viewCode"].map {|c| base_url + "#{color['id']}_#{c}?wid=425" }
        size_ids = color["sizes"].map {|s| s["id"] }.compact.uniq.flatten
        colors_info << {image_url: color_image_url,
                        sizes: product["skusInfo"].map {|i| i["size"] if size_ids.include?(i["sizeId"]) }.compact.uniq.flatten,
                        images: item_images,
                        color_item_url: item_url,
                        import_key: "#{item_import_key}_#{color['id']}"
        }
      end
      return {colors: colors_info, description: description, more_info: more_info, prices: [price, msrp]}
    end
  end
end