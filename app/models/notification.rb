class Notification < ActiveRecord::Base
  serialize :custom_data, Hash
  belongs_to    :user

  scope :unseen, -> {where(seen: false)}
  scope :seen, -> {where(seen: true)}
end