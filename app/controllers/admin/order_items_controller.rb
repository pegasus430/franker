module Admin
  class OrderItemsController < AdminController
    
    def edit
      @order_item = OrderItem.find(params[:id])
      if params[:retailer_order_id].present?
        @retailer_order = RetailerOrder.find(params[:retailer_order_id])
      end
    end
    
    def update
      @order_item = OrderItem.find params[:id]
      if @order_item.update(order_item_params)
        flash[:notice] = "Order has updated"
      else
        flash[:notice] = "Order has not updated, Errors: #{@order_item.errors.full_messages.join(",")}"
      end
      if params[:retailer_order_id].present?
        redirect_to admin_retailer_order_path(params[:retailer_order_id])
      else
        redirect_to admin_order_path(@order_item.order_id)
      end
    end

      protected
      def order_item_params
        params.require(:order_item).permit(:size, :color)
      end
    
  end
end