module Admin
  class StoresController < AdminController
    def index
      @stores = Store.all
    end

    def update
      @store = Store.find params[:id]
      params[:store][:shipping_price] = @store.convert_to_cents(store_params[:shipping_price])
      params[:store][:min_threshold_amount] = @store.convert_to_cents(store_params[:min_threshold_amount])
      if @store.update_attributes store_params
        flash[:success] = "Store preferences have been saved"
        redirect_to admin_root_path
      else
        flash.now[:error] = "Please correct following errors"
        render :edit
      end
    end

    def show
      @store = Store.find params[:id]
    end

    def deactivate
      @store = Store.find params[:store_id]
      @store.active = false
      @store.save!
      redirect_to :back
    end

    def activate
      @store = Store.find params[:store_id]
      @store.active = true
      if !params[:silent].present?
        @store.activation_date = DateTime.now
       end
      @store.save!
      redirect_to :back
    end

    def edit
      @store = Store.find params[:id]
    end

    def destroy
      @store = Store.find(params[:id])
      @store.destroy
      redirect_to admin_root_path
    end

    def trending
      @store = Store.find params[:store_id]
      @store.items.where(trending: true).each do |item|
        item.update_attribute(:trending, false)
      end
      redirect_to :back
    end

    protected
      def store_params
        params.require(:store).permit(:url, :position, :payment, :more_info, :min_threshold_amount, :shipping_price, :logo_icon, :square_logo_icon, :circle_logo_icon)
      end
  end
end