class Api::V1::UsersController < ApplicationController
  respond_to :json

  def register
    @user = User.find_or_create_by(imei: params[:imei])
    if @user.save
      render json: @user
    else
      render json: { errors: @user.errors.as_json, status: "Failure" }, status: 422
    end
  end

  def show
    @user = User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])
    if @user.nil? && params[:old_id].present?
      @user = User.find_by_imei(params[:old_id])
      @user.update(imei: params[:id]) unless @user.nil?
    end
    respond_with @user
  end

  def get_users
    @users = User.where("created_at > ?", DateTime.now - 3.days)
    respond_with @users
  end

  def update
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    params[:user] = {last_activity_at: DateTime.now} if params[:update_last_activity]
    params[:user] = {current_sign_in_at: DateTime.now} if params[:session_started]
    if @user.present? && @user.update_attributes(user_params)
      render json: @user
    else
      errors = @user.present? ? @user.errors.as_json : "User not present"
      render json: { errors: errors, status: "Failure" }, status: 422
    end
  end

  def force_upgrade
    @user = User.find(1)
    respond_with @user
  end

  def make_notifications_seen
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    @notification = @user.notifications.find(params[:notification_id])
    @notification.update_attribute(:seen, true)
    render json: @notification
  end

  def create_payment
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    @order = @user.orders.new
    response_data = @order.create_payment(params, @user)
    response = response_data[:response]
    render json: response
  end

  def find_sales_tax
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    tax_amount = @user.find_sales_tax(params[:zipcode])
    render json: {sales_tax_amount: tax_amount}
  end
  
  #######################
  ## Braintree Methods ##
  #######################
  def braintree_client_token
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    @user.find_or_create_customer
    @token = Braintree::ClientToken.generate(
      :customer_id => @user.customer_id
    )
    if @token.present?
      render json: {status: "Success", token: @token, user_id: @user.id, user_uuid: @user.uuid}
    else
      render json: {status: "Failure", token: @token}
    end
  end
  
  def update_payment_details
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    if params[:shipping_address].present?
      @address_details = @user.add_address_details(params)
    end
    if params[:card_details].present?
      @card_details = @user.add_card_details(params)
    end
    @data = {address_details: @address_details, card_details: @card_details, default_payment_method: @user.get_default_payment_method_hash}
    respond_with @data
  end
  
  def get_detail_of_card
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    if @user.present?
      @default_payment_method_hash = @user.get_default_payment_method_hash
    end
    respond_with @user
  end
  
  def default_payment_method
    @user = (User.find_by_uuid(params[:id]) || User.find_by_imei(params[:id])) || (User.find_by_uuid(params["id"]) || User.find_by_imei(params["id"]))
    render json: @user.get_default_payment_method_hash
  end
  

  private
  def user_params
    params.require(:user).permit(:name, :email, :imei, :uuid, :last_activity_at, :dev_token, :timezone, :current_sign_in_at)
  end
end