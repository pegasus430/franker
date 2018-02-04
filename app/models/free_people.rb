class FreePeople < Cj

  ADVERTISER_ID = 3824326
  CATEGORY_NAMES = ["Swimwear", "Bras", "Underwear Slips", " Boots", "Jeans", "Underwear",
    "Shorts", "Shirts & Blouses", "Shirts & Tops", "Hair Accessories", "Lingerie", "Dresses",
    " Camisoles & Tank Tops", "Loungewear", "Sweaters & Cardigans", " Sandals", "Small Animal Supplies",
    " Athletic Shoes & Sneakers", "Jewelry Sets", "Coats & Jackets", "Gift Giving", "Handbags", "Belts",
    "Pants", "Socks", "Activewear", "Skirts", "Sunglasses", "Denim", "Hats", "Scarves & Shawls", "Jewelry",
    "Gloves & Mittens", "SALE", "Jewelry Sets", " Camisoles & Tank Tops", " Boots", " Athletic Shoes & Sneakers",
    " Sandals", "Underwear Slips", "Dresses", "Skirts", "Loungewear", "Handbags", "Pants", "Shirts & Blouses",
    "Hats", "Shirts & Tops", "Coats & Jackets", "Jeans", "Shorts", "Sweaters & Cardigans", "Swimwear",
    "Jewelry", "Bras", "Scarves & Shawls", "Hair Accessories", "Belts", "Sunglasses", "Small Animal Supplies"]

  class << self
    def store_items
      @store = Store.find_by(name: "Free People")
      create_items(@store, FreePeople::ADVERTISER_ID, FreePeople::CATEGORY_NAMES)

      # # Inactivating items with wrong images
      # @store.items.active_and_unsold.find_each do |item|
        # item.update(active: false) unless item.image.present? &&
                                          # item.image.file.present? &&
                                          # item.image.file.url.present? &&
                                           # item.image.file.url.include?(item.import_key.split("_")[1])
        # item.update(active: false) unless item.item_colors.active.present?
      # end
    end
    
    def debug_import_key(store, product)
      "#{store.name.downcase.split(' ').join('')}_#{product.image_url.split('/')[-1].split("?")[0].split("_")[0]}"
    end
    
    def corrected_name(name)
      name = name.split("Free People ").last.strip
    end
    
  end
end