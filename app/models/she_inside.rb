class SheInside < Cj

  ADVERTISER_ID = 3773223


  class << self
    def store_items
      @store = Store.find_by(name: "Sheinside")
      create_items(@store, SheInside::ADVERTISER_ID)
    end
  end
end