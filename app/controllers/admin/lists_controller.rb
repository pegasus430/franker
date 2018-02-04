module Admin
  class ListsController < AdminController
    before_filter :find_list, only: [:show, :update, :edit, :destroy]
    def index
      @lists = List.all
      # @items = @store.items.includes(:image, :category).order(trending: :desc, created_at: :desc).page(params[:page]).per(100)
      # @items = @items.starts_with(params[:query]) if params[:query].present?
    end

    def create
      @list = List.create(list_params)
      if @list.save
        redirect_to admin_lists_path
      else
        flash[:error] = @list.errors.full_messages
        render "new"
      end
    end


    def new
      @list = List.new
    end

    def show
      @item_list = @list.item_lists.build
    end

    def create_item_lists
      @list = List.find(params[:list_id])
      @item_list = @list.item_lists.create(item_list_params)
      if @item_list.present? && @item_list.persisted?
        redirect_to admin_list_path(@list)
      else
        flash[:error] = @item_list.errors.full_messages
        redirect_to admin_list_path(@list)
      end
    end

    def update_item_list
      @list = List.find(params[:list_id])

      @item_list = @list.item_lists.find(params[:id])
      if @item_list.present? && @item_list.update(item_list_params)
        redirect_to admin_list_path(@list)
      else
        flash[:error] = @item_list.errors.full_messages
        redirect_to :back
      end
    end

    def destroy
      @list.destroy
      redirect_to admin_lists_path
    end

    def destroy_item_list
      @list = List.find(params[:list_id])
      @item_list = @list.item_lists.find(params[:id])
      @item_list.destroy
      redirect_to admin_list_path(@list)
    end

    def activate
      @list = List.find(params[:list_id])
      if @list.update_attributes(active: true)
        flash[:notice] = "List activated successfully"
        redirect_to admin_lists_path
      else
        flash[:notice] = "List not activated successfully"
        redirect_to admin_lists_path
      end
    end

    def deactivate
      @list = List.find(params[:list_id])
      if @list.update_attributes(active: false)
        flash[:notice] = "List de-activated successfully"
        redirect_to admin_lists_path
      else
        flash[:notice] = "List not de-activated successfully"
        redirect_to admin_lists_path
      end
    end

    def edit
    end

    def edit_item_list
      @list = List.find(params[:list_id])
      @item_list = @list.item_lists.find(params[:id])
    end

    def update
      if @list.update_attributes(list_params)
        flash[:notice] = "List updated successfully"
        redirect_to admin_lists_path
      else
        flash[:error] = "List not updated successfully"
        render "edit"
      end
    end

    def find_list
      @list = List.find(params[:id])
    end

    # PUT /admin/lists/dote_picks_icon
    def dote_picks_icon
      if DoteSettings.first.image
        DoteSettings.first.image.update_attributes({file: params["file"]})
      else
        image = Image.new({file: params["file"]})
        image.save
        DoteSettings.first.update_attributes({image: image})
      end
      flash[:notice] = "Successfully Updated"
      redirect_to admin_lists_path
    end

    private

    def list_params
      params.require(:list).permit(:name, :designer_name, :designer_url, :cover_image, :content_square_image, :created_at, :updated_at)
    end

    def item_list_params
      params.require(:item_list).permit(:quote, :item_id, :list_id, :created_at, :updated_at, :position)
    end
  end
end