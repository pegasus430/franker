module Admin
  class OrdersController < AdminController
    def index
      @orders = Order.all.order(created_at: :desc)
    end

    def show
      @order = Order.find(params[:id])
    end

    def submit_for_settlement
      @order = Order.find(params[:order_id])
      result = @order.submit_for_settlement
      if @order.shipped?
        flash[:notice] = "The Order #{@order.id} has been #{result.transaction.status}"
      else
        flash[:error] = "The Order #{@order.id} has not been settled, errors: #{result.errors.map {|e| e.message }}"
      end
      redirect_to admin_orders_path
    end
    
    def void(log_void=false)
      @order = Order.find(params[:order_id])
      if @order.order_placed? || @order.confirmed?
        result = Braintree::Transaction.void(@order.transaction_id)
      end
      if !result.nil? && result.transaction.present?
        if log_void
          EventLogger.log_order_sold_out(@order)
        end
        @order.update(status: 5)
        flash[:notice] = "The Order #{@order.id} has been #{result.transaction.status}"
      else
        flash[:error] = "The Order #{@order.id} has not been voided, errors: #{result.errors.map {|e| e.message }}"
      end
      redirect_to admin_orders_path
    end

    def sold_out
      void(true)
    end

    def edit
      @order = Order.find params[:id]
    end

    def update
      @order = Order.find params[:id]
      if @order.update(order_params)
        flash[:notice] = "Order has updated"
      else
        flash[:notice] = "Order has not updated, Errors: #{@order.errors.full_messages.join(",")}"
      end
      redirect_to admin_orders_path
    end

      protected
      def order_params
        params.require(:order).permit(:item_id, :total_amount, :item_amount, :sales_tax_amount, :user_id, :created_at, :updated_at, :status, :address_id, :customer_id, :retailer_order_id)
      end
  end
end