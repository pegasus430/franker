module Admin
  class CategoriesController < AdminController

    def new
      @category = Category.new
    end

    def create
      @category = Category.create(category_params)
      if @category.save
        redirect_to admin_categories_path(store_id: @category.store_id)
      else
        render "new"
      end
    end

    def destroy
      @category = Category.find(params[:id])
      if @category.sub_categories.present?
        flash[:notice] = "Selected Category has sub categories, please remove them."
      else
        @category.destroy
      end
      redirect_to admin_categories_path(store_id: @category.store_id)
    end

    def edit
      @category = Category.find(params[:id])
    end

    def update
      @category = Category.find(params[:id])
      if @category.update_attributes(category_params)
        redirect_to admin_categories_path(store_id: @category.store_id)
      else
        render "edit"
      end
    end

    def index
      @categories = Category.all
      @store_categories = @categories.includes(:store, :parent).internal_for_store.
                          search_store(params[:store_id])
      if params[:sale].present? && params[:non_sale].present?
        @external_categories = @categories.includes(:store, :parent).external.
                            search_store(params[:store_id])
      else
        @external_categories = @categories.includes(:store, :parent).external.
                            search_store(params[:store_id]).search_sale(params[:sale]).search_non_sale(params[:non_sale])
      end
    end

    def filter_by_store
      @store = Store.find(params[:store_id])
      @category = Category.find(params[:id]) if params[:id].present?
      @categories = @store.categories.internal_for_store
      respond_to do |format|
        format.js
      end
    end

    def show
      @category = Category.find(params[:id])
      @items = @category.items.includes(:image).active_and_unsold.order(created_at: :desc)
      @items = @items.starts_with(params[:query]) if params[:query].present?
    end

    private

    def category_params
      params.require(:category).permit(:name, :url, :category_type, :overall_category, :parent_id, :updated_at, :created_at, :store_id, :special_tag, :special)
    end

  end
end