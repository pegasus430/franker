class SocialNotificationWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :backtrace => true

  def perform(uids, item_id, user_id, message)
    users = User.where(id: uids)
    user = User.find(user_id)
    users.find_each do |u|
      if u.items.pluck(:id).include?(item_id) && u != user
        n = u.notifications.find_or_create_by(message: message, notification_type: "social", seen: false, priority: 3)
        n.custom_data = {store_id: nil, type: "social", item_id: item_id}
        n.save
        puts "$" * 30
        puts "Notification created for social: #{n.inspect}"
        puts "$" * 30
        30.times { puts "" }
      end
    end
  end
end