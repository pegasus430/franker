require 'houston'
class SilentNotificationsWorker
  include Sidekiq::Worker
  include Sidekiq::Benchmark::Worker
  sidekiq_options :queue => :silent_notification, :backtrace => true, :unique => true

  def perform
    benchmark do |bm|
      bm.silent_notification_metric do
        User.non_admin.find_each do |user|
          @user = user
          if @user.dev_token
            token = @user.dev_token
            if Rails.env == "production"
              apn = Houston::Client.production
              apn.certificate = File.read(Rails.root.join("config/DOTE_MAIN.pem"))
            end
            if Rails.env == "staging"
              apn = Houston::Client.production
              apn.certificate = File.read(Rails.root.join("config/dote-prod-app.pem"))
            end
            # #our certificate, which should be available for your app
            if apn.present?
              apn.passphrase = "123456"
              badge_count = get_count_for_all_stores(@user)
              if badge_count > 0
                @notification = Houston::Notification.new(device: token)

                @notification.badge = badge_count
                @notification.sound = "sosumi.aiff"
                @notification.content_available = true

                apn.push(@notification)
                puts "Notification Sent to: @{user.inspect}"
              end
            end
          end
        end
      end
    end
  end

  def get_count_for_all_stores(user)
    item_ids = user.user_items.pluck(:item_id)
    store_new_item_counts = Item.active_and_unsold.new_ones.where.not(id: item_ids).select("store_id, COUNT(*) as count").group("store_id")
    
    count = 0
    if store_new_item_counts.present?
      store_new_item_counts.each do |item_count_object|
        if item_count_object.count > 10
          count = count + 1
        end
      end
    end
    
    return count
  end
end