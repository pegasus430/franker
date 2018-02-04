module Admin
  class UsersController < AdminController

    def edit
      @user = User.find(params[:id])
      @settings = DoteSettings.last
      @retailer_order = RetailerOrder.find(params[:retailer_order_id])
    end

    def update
      @user = User.find(params[:id])
      if @user.admin? && @user.update_attributes(user_params)
        redirect_to root_url
      else
        if @user.update(user_params)
          flash[:notice] = "User has been updated"
        else
          flash[:error] = "User has not been updated, Errors: #{@user.errors.full_messages.join(",")}"
        end
        redirect_to admin_retailer_order_path(params[:retailer_order_id])
      end
    end

    def update_settings
      @setting = DoteSettings.last
      if @setting.update_attributes dote_settings_params
        redirect_to root_url
      else
        redirect_to :back
      end
    end

    def deletion
      @user = User.find(params[:user_id])
    end

    def destroy_individual
      if params[:users][:uuid].present?
        @user = User.find_by(uuid: params[:users][:uuid])
      end
      if params[:users][:imei].present?
        @user = User.find_by(imei: params[:users][:imei])
      end
      if @user.present?
        @user.destroy
        redirect_to root_path
      else
        flash[:error] = "User not destroyed"
        render :deletion
      end
    end

    def settings
      # @setting = Settings.new
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :uuid, :imei, :force_upgrade, :appstore_url, :updated_at)
    end

    def dote_settings_params
      params.require(:settings).permit(:batch_time)
    end

  end
end