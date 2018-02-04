class AnnTaylor < Cj

  ADVERTISER_ID = 3818674

  class << self
    def store_items
      @store = Store.find_by(name: "Ann Taylor")
      create_items(@store, AnnTaylor::ADVERTISER_ID)
    end
    
    def debug_import_key(store, product)
      image_id = CGI.parse(URI.parse(product.image_url).query)["imageId"][0]
      "#{store.name.downcase.split(' ').join('')}_#{image_id}"
    end
    
    def corrected_name(name)
      name = name.split("Ann Taylor ").last.strip
      name.split("-").first.strip
    end
  end
end