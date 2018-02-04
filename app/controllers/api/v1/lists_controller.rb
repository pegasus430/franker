class Api::V1::ListsController < ApplicationController
  respond_to :json

  def index
    @list_ids = current_user.user_lists.order(seen_at: :asc).map(&:list_id)
    if @list_ids.present?
      @lists = List.active.includes(:item_lists).where.not(id: @list_ids).order(created_at: :desc) + List.active.includes(:item_lists).where(id: @list_ids).order("field(id, #{@list_ids.join(',')})")
    else
      @lists = List.active.includes(:item_lists).order(created_at: :desc)
    end
    @lists = @lists.select {|l| l if l.item_lists.present? && l.item_lists.count > 0}
    respond_with @lists
  end

  def show
    @list = List.find(params[:id])
    @item_lists = @list.item_lists.order(position: :desc).select {|list| list if list.item.present? }
    respond_with @list
  end

  def create_user_list
    @list = List.find(params[:list_id])
    @user_list = @list.user_lists.find_or_create_by(user_id: current_user.id)
    if @user_list.present? && params[:seen] == "true"
      @user_list.seen_at = DateTime.now
      @user_list.save!
    end
    render json: {success: true}
  end

end