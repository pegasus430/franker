module Admin
  class RetailerOrdersController < AdminController
    def index
      @retailer_orders = RetailerOrder.all.includes(:orders).order(id: :desc)
    end
    
    def show
      @retailer_order = RetailerOrder.find(params[:id])
    end
    
    def edit
      @retailer_order = RetailerOrder.find(params[:id])
    end
    
    def new
      @retailer_order = RetailerOrder.new
      @retailer_order.save!
    end
  
    def update
      @retailer_order = RetailerOrder.find(params[:id])
      if @retailer_order.update(retailer_order_params)
        flash[:notice] = "Retailer Order has updated"
      else
        flash[:notice] = "Retailer Order has not updated, Errors: #{@retailer_order.errors.full_messages.join(",")}"
      end
      redirect_to admin_retailer_order_path(params[:id])
    end
    
    def email_confirmation
      @retailer_order = RetailerOrder.find params[:retailer_order_id]
      silently = params[:silently].present? ? params[:silently] : false
      if @retailer_order.confirmation_number.nil?
        flash[:error] = "Error: Confirmation number required to send confirmation email"
      else
        @retailer_order.order_confirmed
        flash[:notice] = "Successfully sent confirmation email"
        AdminAlertMailer.confirmation(@retailer_order, silently).deliver
      end
      redirect_to admin_retailer_orders_path
    end
    
    def submit_for_settlement_and_email_shipping_confirmation
      @retailer_order = RetailerOrder.find params[:retailer_order_id]
      silently = params[:silently].present? ? params[:silently] : false
      if @retailer_order.confirmation_number.nil?
        flash[:notice] = "Error: Confirmation number required to send shipping confirmation"
      else
        settlement_successful, errors = @retailer_order.submit_for_settlement
        if settlement_successful
          flash[:notice] = "Retailer Order #{@retailer_order.id} has been successfully submitted"
          AdminAlertMailer.shipping(@retailer_order, silently).deliver
        else
          if result.nil?
            flash[:error] = "Retailer Order #{@retailer_order.id} has not been settled."
          else
            flash[:error] = "Retailer Order #{@retailer_order.id} has not been settled, errors: #{errors.map {|e| e.message }}"
          end
        end
      end
      redirect_to admin_retailer_orders_path
    end

    protected
    def retailer_order_params
      params.require(:retailer_order).permit(:confirmation_number, :tracking_number, :tracking_url, :notes)
    end
  end
end