module Admin
  class AddressesController < AdminController
    
    def edit
      if params[:retailer_order_id].present?
        @retailer_order = RetailerOrder.find(params[:retailer_order_id])
        @order = @retailer_order.orders.count > 0 ? @retailer_order.orders[0] : nil
      else
        @order = Order.find(params[:order_id])
      end
      @address = @order.address
    end
    
    def update
      @address = Address.find params[:id]
      if @address.update(addresses_params)
        flash[:notice] = "Address has updated"
      else
        flash[:notice] = "Address has not updated, Errors: #{@address.errors.full_messages.join(",")}"
      end
      
      if params[:retailer_order_id].present? 
        redirect_to admin_retailer_order_path(params[:retailer_order_id])
      elsif params[:order_id].present?
        redirect_to admin_order_path(params[:order_id])
      else
        redirect_to admin_retailer_orders_path
      end
    end
    
    protected
    def addresses_params
      params.require(:address).permit(:street_address, :city, :state, :country)
    end
  end
end