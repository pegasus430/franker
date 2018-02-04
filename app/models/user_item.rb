class UserItem < ActiveRecord::Base

  belongs_to :user
  belongs_to :item

  scope :unseen, -> {where(seen: false)}
  scope :seen, -> {where(seen: true)}
  scope :favorite, -> {where(favorite: true, seen: true)}

end