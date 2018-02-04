class VictoriaSecret < Shopsense
  SHOPSENSE_ID = 2335
  class << self
    def store_items
      store = Store.find_by(name: "Victoria Secret")
      pink_store = Store.find_by(name: "Pink")
      create_items(store, VictoriaSecret::SHOPSENSE_ID, pink_store, "PINK")
    end
  end
end