module Admin
  class ItemsController < AdminController
    before_filter :find_store
    def index
      @items = @store.items.includes(:image, :category, :item_lists, :lists).order(trending: :desc, created_at: :desc).page(params[:page]).per(100)
      @items = @items.starts_with(params[:query]) if params[:query].present?
    end

    def new
      @item = @store.items.build
    end

    def show
      @item = @store.items.includes(:item_colors).includes(item_colors: :images).includes(item_colors: :image).find(params[:id])
    end

    def destroy
      @item = @store.items.find(params[:id])
      @item.destroy
      redirect_to admin_root_path
    end

    def trending
      @item = @store.items.includes(:image).find(params[:item_id])
      if request.request_method == "POST"
        @item.update_attribute(:trending, true)
      end
      if request.request_method == "DELETE"
        @item.update_attribute(:trending, false)
      end
      redirect_to :back
    end

    def deactivate
      @item = @store.items.includes(:image).find(params[:item_id])
      @item.active = false
      @item.save!
      redirect_to :back
    end

    def add_lists
      @item = @store.items.includes(:image).find(params[:item_id])
      @item.lists << List.where(id: params[:lists])
      puts "Item Lists : #{@item.item_lists}"
      redirect_to :back
    end

    def activate
      @item = @store.items.find(params[:item_id])
      @item.active = true
      @item.save!
      redirect_to :back
    end

    def edit
      @item = @store.items.find(params[:id])
    end

    def update
      @item = @store.items.find(params[:id])
      if @item.update_attributes(item_params)
        flash[:notice] = "Item updated successfully"
        redirect_to :back
      else
        flash[:error] = "Item not updated successfully"
        redirect_to :back
      end
    end

    def find_store
      @store = Store.find(params[:store_id])
    end
    private

    def item_params
      params.require(:item).permit(:name, :url, :image_id, :price, :created_at, :updated_at, :msrp, :import_key, :store_id, :category_id)
    end
  end
end