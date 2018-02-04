class JuicyCouture < Ebay
  ADVERTISER_ID = 5571
  class << self
    def image_url_from(row)
      row.image_url
    end

    def import_key_for(row)
      "juicy_couture_#{row.image_url.gsub(/[^\d]/, "")}"
    end

    def store_items
      store = Store.find_by(name: "Juicy Couture")
      create_items(store.name, JuicyCouture::ADVERTISER_ID)
    end
  end
end