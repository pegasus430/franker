class ItemColor < ActiveRecord::Base
  serialize     :sizes, Array

  belongs_to :item
  belongs_to :image, dependent: :destroy
  has_many   :images, :as => :imageable, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :valid, -> { where("color IS  NOT NULL OR image_id IS NOT  NULL") }
  validates_uniqueness_of :import_key
end
