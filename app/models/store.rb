class Store < ActiveRecord::Base

  belongs_to    :image, dependent: :destroy
  has_many      :images, :as => :imageable, dependent: :destroy
  has_many      :items
  has_many      :categories
  has_many      :order_items
  has_many      :users, through: :user_favorite_stores
  has_many      :user_favorite_stores, dependent: :destroy
  validates     :position, numericality: { greater_than: 0 }, if: 'position.present?'
  
  mount_uploader :logo_icon, FileUploader
  mount_uploader :square_logo_icon, FileUploader
  mount_uploader :circle_logo_icon, FileUploader

  before_save   :set_position, if: 'new_record?'
  scope :active, -> { where(active: true) }

  JCREW = "https://www.jcrew.com/search2/index.jsp?N=21+17&Ntrm=&Nsrt=3&Npge=1"
  MADEWELL = "https://www.madewell.com/search/searchNavigation.jsp?eneQuery=Nao%3D0%26Nk%3Dall%26Ne%3D1%2B2%2B3%2B22%2B4294967294%2B20%2B225%26Nu%3DP_productid%26N%3D20%2B17&NUM_ITEMS=90&FOLDER%3C%3Efolder_id=1408474395181138&bmUID=krjm34_"
  ANTHROPOLOGIE = "http://www.anthropologie.com/anthro/category/clothing/shopsale-clothing.jsp?&id=SHOPSALE-CLOTHING&itemCount=100&startValue=1"
  LULULEMON = "http://shop.lululemon.com/products/category/women-we-made-too-much?lnid=ln;women;we-made-to-much"
  ARITZIA = "http://aritzia.com/en/sale"
  BRANDYMELVILLE = "http://www.brandymelvilleusa.com"
  ABERCROMBIE = "http://www.abercrombie.com/shop/wd/womens"
  ZARA = "http://www.zara.com/us/"

  def isFavorite!(user)
    user_favorite_stores.find_by(user_id: user.id, favorite: true).present?
  end

  def convert_to_cents(price)
    price = (price.present? && price != 0) ? price.to_f * 100 : 0
    price.to_i
  end

  def current_position(user)
    @ufs = user_favorite_stores.find_by(user_id: user.id)
    @ufs.present? ? @ufs.position : 0
  end

  def self.order_by_position(user = nil)
    if user.present?
      user.user_favorite_stores.where("position > 0").order(position: :desc, updated_at: :desc).pluck(:store_id)
    else
      order('stores.position ASC')
    end
  end

  def new_items_count(user)
    item_ids = user.user_items.pluck(:item_id)
    @items_count = items.active_and_unsold.new_ones.where.not(id: item_ids).count
    @items_count
  end

  def new_sale_items_count(user)
    @ufs = UserFavoriteStore.find_by(user_id: user.id, store_id: self.id)
    if @ufs.present?
      items.active_and_unsold.unseen.new_ones.includes(:category).
      joins("LEFT JOIN user_items ON user_items.item_id = items.id AND user_items.user_id = #{user.id}").
      where("user_items.id is null AND items.created_at > ? ", @ufs.created_at).select {|i| i if i.sale? }.count
    else
      nil
    end
  end

  def set_position
    max_value = Store.maximum(:position)
    self[:position] = max_value.present? ? max_value + 1 : 1
  end
  
  def is_new_store(user)
    last_session_start_datetime = user.current_sign_in_at
    if last_session_start_datetime.nil? || self[:activation_date].nil?
      return false
    end
    return last_session_start_datetime < self[:activation_date]
  end
end