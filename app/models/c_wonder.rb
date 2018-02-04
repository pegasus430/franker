class CWonder < Ebay
  ADVERTISER_ID = 6165
  class << self
    def image_url_from(row)
      "#{row.image_url}&wid=1080&fmt=jpg"
    end

    def import_key_for(row)
      "c_wonder_#{row.image_url.gsub(/[^\d]/, "")}"
    end

    def store_items
      store = Store.find_by(name: "C Wonder")
      create_items(store.name, CWonder::ADVERTISER_ID)
    end
  end
end