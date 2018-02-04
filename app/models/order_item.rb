class OrderItem < ActiveRecord::Base
  serialize :item_data, Hash
  belongs_to      :order
  belongs_to      :item
  belongs_to      :store

end