class Api::V1::OrdersController < ApplicationController
  respond_to :json

  def create
    @user = User.find_by_uuid(params[:uuid])
    @order = @user.orders.new
    reponse_data = @order.create_payment(params, @user)
    response = reponse_data[:response]
    if @order.order_placed?
      @order.find_retailer_order
    end
    render json: response
  end

  private

  def order_params
    params.require(:order).permit(:transaction_id, :customer_id, :user_id, :amount, :status, :address_id)
  end
end