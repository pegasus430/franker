class Comment < ActiveRecord::Base

  belongs_to            :item
  belongs_to            :user

  validates_presence_of :message

  def user_name
    user.present? ? user.name : ""
  end
end