require 'houston'
class IosWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true, :unique => true

  def perform
    User.non_admin.find_each do |user|
      @user = user
      puts "Am in User Loop"
      puts "User: #{@user.inspect}"
      
      if @user.dev_token && @user.notifications.unseen.size > 0
        puts "User has dev token"
        token = @user.dev_token
        destroy_unnecessary_notifications(@user) if @user.notifications.count > 0
        notifications_logger.info "------------- Sending notifs -------------"
        notif = @user.notifications.unseen.where(priority: 1).take || @user.notifications.unseen.where(priority: 2).take || @user.notifications.unseen.where(priority: 3).take || @user.notifications.unseen.where(priority: 4).take
        notifications_logger.info "------------- Notification Object: #{notif.inspect} -------------"
        puts "Notification Object: #{notif.inspect}"
        puts "Rails.env = #{Rails.env}"
        if Rails.env == "production"
          apn = Houston::Client.production
          puts "Am in production mode"
          notifications_logger.info "Am in production mode"
          apn.certificate = File.read(Rails.root.join("config/DOTE_MAIN.pem"))
        elsif Rails.env == "staging"
          apn = Houston::Client.production
          puts "Am in staging mode"
          notifications_logger.info "Am in staging mode"
          apn.certificate = File.read(Rails.root.join("config/dote-prod-app.pem"))
        else
          apn = Houston::Client.development
          puts "Am in development mode"
          apn.certificate = File.read(Rails.root.join("config/dote-dev-app.pem"))
        end
        # our certificate, which should be available for your app
        apn.passphrase = "123456"

        if notif.present?
          @notification = Houston::Notification.new(device: token)
          @notification.sound = "sosumi.aiff"
          @notification.content_available = true
          notifications_logger.info "Notification message: #{notif.message}"
          @notification.alert = notif.message
          @notification.custom_data = notif.custom_data.merge({notification_id: notif.id})
          puts "Actual notification: #{@notification.inspect}"
          2.times {notifications_logger.info "" }
          notifications_logger.info "Actual notification: #{@notification.inspect}"
          puts "Actual APN Object: #{apn.inspect}"
          2.times {notifications_logger.info "" }
          notifications_logger.info "Actual APN Object: #{apn.inspect}"
          apn.push(@notification)
          puts "Notification Sent"
          notifications_logger.info "Notification Sent to User: uuid: #{@user.uuid}, imei: #{@user.imei}, email: #{@user.email}"
          4.times {notifications_logger.info "" }
        end
      end
    end
  end

  def notifications_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/favorite_notifications.log")
  end


  def destroy_unnecessary_notifications(user)
    user.notifications.seen.destroy_all
    notifications_logger.info "------------- Destroying un-necessary notifs -------------"
    user.notifications.unseen.each do |notif|
      begin
        item = Item.find(notif.custom_data[:item_id]) if notif.custom_data[:item_id].present?
      rescue Exception => e
        puts "Item Not found"
      end
      unless item.nil? && (item.price != item.msrp && item.msrp != 0) && item.active && !item.sold_out
        notifications_logger.info "------- Notif Details -------"
        notifications_logger.info "Destroying notif : #{notif.inspect}"
        2.times {notifications_logger.info "" }
        notifications_logger.info "------- Item Details -------"
        notifications_logger.info "Item Details : #{item.inspect}"
        notif.destroy
        notifications_logger.info "------- Destroyed Notif -------"
        2.times {notifications_logger.info "" }
      end
    end
  end

  def get_count_for_all_stores(user)
    Store.active.inject(0) do |count, store|
      items_count = store.new_items_count(user)
      items_count ||= 0
      items_count > 10 ? (count + 1) : count
    end
  end
end