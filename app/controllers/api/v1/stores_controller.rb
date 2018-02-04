class Api::V1::StoresController < ApplicationController
  respond_to :json

  def index
    if current_user.user_favorite_stores.count > 0
      store_ids = Store.includes(:image).active.order_by_position(current_user)
      @stores = Store.includes(:image).active.where(id: store_ids).sort_by {|x| store_ids.index(x.id).to_i} + Store.includes(:image).active.where.not(id: store_ids)
    else
      @stores = Store.includes(:image).active.order_by_position
    end
    favorite_stores = current_user.user_favorite_stores.where(favorite: true)
    if favorite_stores.present?
      @favorite_store_ids = favorite_stores.pluck(:store_id)
    else
      @favorite_store_ids = []
    end
    
    respond_with @stores
  end

  def favorite
    if request.request_method == "POST"
      @ufs = current_user.user_favorite_stores.find_or_create_by(store_id: params[:store_id])
      @ufs.favorite = true
      @ufs.save
    end
    if request.request_method == "DELETE"
      @ufs = current_user.user_favorite_stores.find_or_create_by(store_id: params[:store_id])
      @ufs.favorite = false
      @ufs.save
    end
  end

  def get_stores
    @stores = Store.active.where("id > ?", 11)
    respond_with @stores
  end

  def update_position
    @store = Store.find(params[:store_id])
    json_hash = Hash.new()
    if @store.present?
      user_store = current_user.user_favorite_stores.find_or_create_by(store_id: @store.id)
      user_store.position = params[:numOfHits]
      user_store.save
      json_hash["status"] = "Success"
    else
      json_hash["status"] = "Failure"
    end
    render json: json_hash
  end

  def favorites
    @stores = current_user.user_favorite_stores.includes(:store).map(&:store)
    respond_with @stores
  end

  def new_item_count
    new_item_counts = Hash.new()
    
    item_ids = current_user.user_items.limit(1000).pluck(:item_id)
    if params[:store_id].present?
      store_new_item_counts = Item.active_and_unsold.new_ones.where(store_id: params[:store_id]).where.not(id: item_ids).select("store_id, COUNT(*) as count").group("store_id")
    else
      if params[:favorites].present?
        favorite_store_ids = current_user.user_favorite_stores.where(favorite: true).pluck(:store_id)
        store_new_item_counts = Item.active_and_unsold.new_ones.where(store_id: favorite_store_ids).where.not(id: item_ids).select("store_id, COUNT(*) as count").group("store_id")
      else
        store_new_item_counts = Item.active_and_unsold.new_ones.where.not(id: item_ids).select("store_id, COUNT(*) as count").group("store_id")
      end
    end
    
    if store_new_item_counts.present?
      store_new_item_counts.each do |item_count_object|
        if item_count_object.count > 0
          new_item_counts[item_count_object.store_id] = item_count_object.count > 50 ? "50+" : item_count_object.count
        end
      end
    end
    
    respond_with new_item_counts.to_json
  end
end