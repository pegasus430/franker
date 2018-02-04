class ItemList < ActiveRecord::Base

  belongs_to      :list
  belongs_to      :item

  validates_presence_of :item_id
  validates :quote, length: { maximum: 80 }
  validates :item_id, numericality: { only_integer: true, greater_than: 0 }
  validate :item_valid_or_not
  validate :position_uniqueness_and_value

  # validates_uniqueness_of :position

  def item_valid_or_not
    unless item_id == 0 || Item.active_and_unsold.where(id: item_id).count > 0
      errors.add(:item_id, "is invalid. Item not found with given item_id")
    end
  end

  def position_uniqueness_and_value
    list = self.list
    if self.position.present?
      unless self.position > 0
        errors.add(:position, "is invalid. Position should be greater than 0.")
      end
      if list.item_lists.flat_map(&:position).include?(self.position)
        errors.add(:position, "is invalid. Position is already taken for this list.")
      end
    end
  end
end