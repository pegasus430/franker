class List < ActiveRecord::Base

  has_many      :user_lists, dependent: :destroy
  has_many      :item_lists, dependent: :destroy
  has_many      :items, through: :item_lists
  has_many      :users, through: :user_lists

  mount_uploader :cover_image, FileUploader
  mount_uploader :content_square_image, FileUploader

  scope :active, -> { where(active: true) }

  validates_presence_of :name, :cover_image, :content_square_image
end