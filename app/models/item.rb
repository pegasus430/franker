class Item < ActiveRecord::Base
  @@user_items_method = ""

  serialize     :more_info, Array
  serialize     :size, Array

  has_many      :images, :as => :imageable, dependent: :destroy
  belongs_to    :image, dependent: :destroy
  belongs_to    :store, :counter_cache => true
  belongs_to    :category, :counter_cache => true
  has_many      :users, through: :user_items
  has_many      :user_items, dependent: :destroy
  has_many      :item_colors, dependent: :destroy
  has_many      :lists, through: :item_lists
  has_many      :item_lists, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :trending, -> { where(trending: true) }
  scope :new_ones, -> { where(new_one: true) }
  scope :active_and_unsold, -> { where(active: true, sold_out: false) }
  scope :starts_with, -> (name) { where("name like ?", "#{name}%")}
  scope :unseen, -> { where(user_items_count: 0)}
  scope :new_data_for_store, ->(store) { new_ones.active_and_unsold.unseen.where(store_id: store.id) if store.present? }
  scope :active_unsold_and_on_sale, -> { where("active = true AND sold_out = false AND price < msrp") }

  validates_uniqueness_of :import_key, on: :create

  def self.total_count
    self.count
  end

  def sale_list
    self.select{|i| i if i.sale?}
  end

  def non_sale_list
    self.select{|i| i unless i.sale?}
  end

  def sale?
    price.to_i < msrp.to_i
  end

  def fav_badge_type(user)
    self.sale? ? "SALE" : nil
  end

  def new?
    new_one == true
  end

  def shipping_price
    return 0 unless store.shipping_price.present?
    if store.min_threshold_amount.present? && store.min_threshold_amount > 1
      return store.shipping_price if price.to_i <= store.min_threshold_amount.to_i && store.shipping_price.to_i != 0
      return 0 if price.to_i > store.min_threshold_amount.to_i || store.shipping_price.to_i == 0
    else
      return store.shipping_price if store.shipping_price.to_i != 0
      return 0 if store.shipping_price.to_i == 0
    end
  end

  def ground_shipping_value
    return 0 if store.shipping_price == 0 || store.min_threshold_amount == 0
    return store.shipping_price if store.shipping_price.to_i != 0
  end

  def shipping_details(user, store)
    return {shipping_price: 0, shipping_badge: "Free Shipping", free_shipping_at: nil} if user.orders.blank? && user.orders.count == 0
    last_order = store.order_items.last.order if store.order_items.present? && store.order_items.count > 0
    last_order = (last_order.present? && (last_order.status == "success" || last_order.status == "order_placed")) ? last_order : nil
    last_order_store_id = store.id if last_order.present?
    time_difference_in_min = ((DateTime.now - last_order.created_at.to_datetime) * 24 * 60 * 60).to_i if last_order.present?
    if last_order_store_id.present? && self.store_id == last_order_store_id
      if DoteSettings.last.batch_time.present? && time_difference_in_min > (DoteSettings.last.batch_time * 60)
        {shipping_price: shipping_price, shipping_badge: shipping_badge, free_shipping_at: nil}
      else
        batch_time = DoteSettings.last.batch_time.nil? ? 0 : DoteSettings.last.batch_time.minutes
        {shipping_price: 0, shipping_badge: "Free Shipping", free_shipping_at: last_order.created_at + batch_time}
      end
    else
      {shipping_price: shipping_price, shipping_badge: shipping_badge, free_shipping_at: nil}
    end
  end

  def shipping_badge
    return "Free Shipping" unless store.shipping_price.present?
    if store.min_threshold_amount.present? && store.min_threshold_amount > 1
      return "Free Shipping" if price.to_i > store.min_threshold_amount.to_i || store.shipping_price.to_i == 0
    else
      return "Free Shipping" if store.shipping_price.to_i == 0
    end
  end

  def convert_sizes(size)
    if size.present?
      data = size.map do |s|
        "S" if s == "Fits size Small/Medium" || s == "Fits size Small / Medium "
        "XS" if s == "Fits XS"
        "S" if s == "Fits size Small"
        "S" if s == "Small"
        "M" if s == "Medium"
        "L" if s == "Large"
        "XS" if s == "Fits size X-small"
        "S" if s == "Small/Medium"
        s
      end
    else
      []
    end
  end

  def new_one?(user)
    new? && !seen(user)
  end

  def badge_type(user)
    new_one?(user) ? (sale? ? "New Sale" : "New") : trending ? "Trending" : nil
  end

  def favorite_users
    User.where(id: user_items.favorite.pluck(:user_id))
  end

  def seen(user)
    user_item = user.user_items.where(item_id: :id)
    user_item.present?
  end

  def favorite(user)
    if (@@user_items_method != "favorite")
      @user_items = user_items.where(user_id: user.id, favorite: true)
      @@user_items_method = "favorite"
    end
    (@user_items.present? && @user_items.count > 0) ? true : false
  end

  def send_notification_for_favorite_users(user)
    unless self.store.name == "Anthropologie"
      message = "Check out the #{self.name} from #{self.store.name} I found on Dote! http://bit.ly/1rlprfO"
      if favorite_users.count > 100
        favorite_users.includes(:notifications, :items).find_each do |u|
          if u.items.pluck(:id).include?(self.id) && u != user
            n = u.notifications.find_or_create_by(message: message, notification_type: "social", seen: false, priority: 3)
            n.custom_data = {store_id: nil, type: "social", item_id: self.id}
            n.save
          end
        end
      end
    end
  end
end