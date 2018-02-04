class Api::V1::CommentsController < ApplicationController
  before_filter :current_item
  respond_to :json

  def create
    @comment = current_item.comments.build(user_id: current_user.id, message: params[:message])
    if @comment.save
      render json: @comment
    else
      render json: {status: "Failure", errors: @comment.errors.as_json}
    end
  end

  def index
    @comments = current_item.comments.page(params[:page]).per(10)
    @comments_count = current_item.comments.count
    respond_with @comments
  end

  def current_item
    Item.find(params[:item_id])
  end
end