module Admin
  class ColorsController < AdminController
    def index
      @colors = Color.all
    end

    def create
      @color = Color.create(color_params)
      if @color.persisted?

        flash[:success] = "Color have been saved"
        redirect_to admin_colors_path
      else
        flash.now[:error] = "Please correct following errors"
        render :new
      end
    end

    def new
      @color = Color.new
    end

    def update
      @color = Color.find params[:id]
      if @color.update_attributes color_params
        flash[:success] = "Color have been saved"
        redirect_to admin_colors_path
      else
        flash.now[:error] = "Please correct following errors"
        render :edit
      end
    end

    def show
      @color = Color.find params[:id]
    end

    def edit
      @color = Color.find params[:id]
    end

    def destroy
      @color = Color.find(params[:id])
      @color.destroy
      redirect_to admin_root_path
    end

    protected
      def color_params
        params.require(:color).permit(:name, :hash_value)
      end
  end
end
