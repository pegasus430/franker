require 'algoliasearch'
Algolia.init :application_id => "ZYNHDLTA0N", :api_key => "4cc83654495c33dfed1635560609749b"

class Api::V1::ItemsController < ApplicationController
  respond_to :json

  def index
    search_query = params[:query].present? ? params[:query].split("*").join(" & ").split(",") : []
    @sale = search_query.include?("SALE")
    # original search query is saved for caching key
    # however, we want to remove the "SALE" category from our search query
    original_search_query = search_query
    if @sale
      search_query = search_query[1..-1]
    end

    if params[:store_id] && params[:type] == "store_items"
      @store = Store.find(params[:store_id])
      
      if params[:categoriesdata] == "false"
        # @all_categories = $redis.cached("user:#{current_user.id}:store:#{@store.id}:all_categories", expire: 10.minutes) do
          # only store's (internal/lvl2) categories that actually have items (check sub_categories/external categories)
          @all_categories = @store.categories.internal_for_store.joins(sub_categories: :items).where("items.active = true AND items.sold_out = false").select(:name).uniq.map(&:name)
          sale_items_exist = @store.items.where("active = true AND sold_out = false AND msrp > price").exists?
          if sale_items_exist
            @all_categories = ["SALE"] + @all_categories
          end
          # all_categories
        # end
      end
      
      # @unseen = $redis.cached_list("user:#{current_user.id}:store:#{@store.id}:unseen:#{original_search_query.join('-')}") do
        seen_ids = current_user.user_items.pluck(:item_id).uniq
        ids = params[:item_ids] ? (seen_ids + params[:item_ids].split(",")) : seen_ids

        categories = search_query.present? ? @store.categories.internal_for_store.where(name: search_query).order("RAND()") : []
        
        # Here is where can change active_items to return only sale items
        if categories.empty? && search_query.present?
          @unseen = []
        elsif current_user.created_at > Item.last.created_at
          @unseen = Category.active_items(categories.map(&:id), @sale).includes(:store, :category, :image).where(store_id: @store.id).
                  where.not(id: ids).order("trending desc, rand()", "created_at desc, rand()").page(params[:page]).per(100)
        else
          @unseen = Category.active_items(categories.map(&:id), @sale).includes(:store, :category, :image).where(store_id: @store.id).
                  where.not(id: ids).order("created_at desc", "new_one desc, rand()", "trending desc, rand()").page(params[:page]).per(100)
        end
        # unseen
      # end

      if @unseen.size == 0
        if categories.empty? && search_query.present?
          @seen = []
        else
          seen_ids = current_user.user_items.pluck(:item_id).uniq

          if params[:item_ids] && params[:item_ids].split(",").present?
            @seen = Category.active_items(categories.map(&:id), @sale).includes(:store, :category, :image).where(store_id: @store.id, id: (seen_ids - params[:item_ids].split(",").map(&:to_i))).
                  order("created_at desc", "trending desc, rand()").page(params[:page]).per(10)
            @next_page_no = @seen.next_page if @seen.next_page.present?
          else
            @seen = Category.active_items(categories.map(&:id), @sale).includes(:store, :category, :image).where(store_id: @store.id, id: seen_ids).
                  order("created_at desc", "trending desc, rand()").page(params[:page]).per(10)
            @next_page_no = @seen.next_page.present? ? @seen.next_page : nil
          end
        end
      end
    end

    if params[:type] == "favorite_stores"
      store_ids = current_user.favorite_store_ids
      @seen_ids = current_user.user_items.pluck(:item_id).uniq
      ids = params[:item_ids] ? (@seen_ids + params[:item_ids].split(",")) : @seen_ids

      if params[:categoriesdata] == "false"
        @all_categories = all_categories
      end

      # @unseen = $redis.cached_list("user:#{current_user.id}:favorite_stores:#{store_ids.join(",")}:unseen:#{original_search_query.join('-')}") do
        categories = []
        if search_query.present?
          categories = Category.internal_for_overall.where(name: search_query)
        elsif @sale
          categories = Category.internal_for_overall.includes(:sub_categories)
        end
        
        @unseen = Category.active_items(categories.map(&:id), @sale).where.not(id: ids).includes(:store, :category, :image).where(store_id: store_ids)
                 .order("new_one desc", "trending desc", "rand()").take(10)
      # end
      if @unseen.size == 0
        if params[:item_ids] && params[:item_ids].split(",").present?
          @seen = Category.active_items(categories.map(&:id), @sale).active_and_unsold.includes(:store, :category, :image).where(store_id: store_ids, id: (@seen_ids - params[:item_ids].split(",").map(&:to_i))).
                order(created_at: :desc).page(params[:page]).per(10)
          @next_page_no = @seen.next_page if @seen.next_page.present?
        else
          @seen = Category.active_items(categories.map(&:id), @sale).active_and_unsold.includes(:store, :category, :image).where(store_id: store_ids, id: @seen_ids).
                order(created_at: :desc).page(params[:page]).per(10)
          @next_page_no = @seen.next_page.present? ? @seen.next_page : nil
        end
      end
    end
    @items = (@unseen.size == 0) ? @seen : @unseen
    respond_with @items
  end

  def favorite
    @item = Item.find(params[:item_id])
    if request.request_method == "POST"
      current_user.favorite!(@item, true)
    end
    if request.request_method == "DELETE"
      current_user.favorite!(@item, false)
    end
    respond_with @item
  end

  def show
    @item = Item.find(params[:id])
  end

  def seen
    @item = Item.find(params[:item_id])
    current_user.seen!(@item)
    respond_with @item
  end

  def favorites
    search_query = params[:query].present? ? params[:query].split("*").join(" & ").split(",") : ""
    sale = search_query.include?("SALE")
    @store = params[:store_id].present? ? Store.find(params[:store_id]) : nil
    original_search_query = search_query
    if sale
      search_query = search_query[1..-1]
    end

    @item_ids = current_user.user_items.where(favorite: true).order(sale: :desc, updated_at: :desc).pluck(:item_id)
    if @store.present?
      categories = search_query.present? ? @store.categories.internal_for_store.where(name: search_query) : []
      
      if categories.present?
        category_items = Category.active_items(categories.map(&:id), sale)
        @items = category_items.includes(:store, :image, :category).where(id: @item_ids, store_id: @store.id).active_and_unsold.order(:id).page(params[:page]).per(50)
        parent_ids = Category.where(id: category_items.where(id: @item_ids, store_id: @store.id).active_and_unsold.pluck(:category_id)).pluck(:parent_id)
      else
        @items = Item.includes(:store, :image, :category).where(id: @item_ids, store_id: @store.id).active_and_unsold.order(:id).page(params[:page]).per(50)
        parent_ids = Category.where(id: Item.where(id: @item_ids, store_id: @store.id).active_and_unsold.pluck(:category_id)).pluck(:parent_id)
      end
      store_ids = [@store.id]
      @all_categories = @store.categories.internal_for_store.joins(sub_categories: :items).where("sub_categories_categories.items_count > 0 AND items.active = true AND items.sold_out = false").select(:name).uniq
      @store_filters = ["All Stores"] + (Store.where(id: Item.where(id: @item_ids).pluck(:store_id) - [@store.try(:id)]))
    else
      categories = search_query.present? ? Category.internal_for_overall.where(name: search_query).includes(:sub_categories) : []
      
      if categories.present?
        category_items = Category.active_items(categories.map(&:id), sale)
        @items = category_items.includes(:store, :image, :category, :item_colors, :images).where(id: @item_ids).active_and_unsold.order(:id).page(params[:page]).per(50)
        parent_ids = Category.where(id: category_items.where(id: @item_ids).active_and_unsold.pluck(:category_id)).pluck(:parent_id)
      else
        if sale
          @items = Item.includes(:store, :image, :category).where(id: @item_ids).active_unsold_and_on_sale.order(:id).page(params[:page]).per(50)
        else
          @items = Item.includes(:store, :image, :category).where(id: @item_ids).active_and_unsold.order(:id).page(params[:page]).per(50)
        end
        parent_ids = Category.where(id: Item.where(id: @item_ids).active_and_unsold.pluck(:category_id)).pluck(:parent_id)
      end
      store_ids = Store.active.map(&:id)
      @all_categories = Category.includes(:parent).where(id: parent_ids).map(&:parent).uniq.compact
      @store_filters = Store.where(id: Item.where(id: @item_ids).pluck(:store_id))
    end
  
    @next_page_no = @items.next_page.present? ? @items.next_page : nil
    sort_ids = @items.collect {|ui| "id = #{ui.id}"}
    @main_items = @items
  
    @items = @main_items.where(store_id: store_ids).order(sort_ids.join(', ')).reverse
    respond_with @items
  end
  
  def more_info
    @current_item = Item.find(params[:item])
    @similar_items = @current_item.category.items.active_and_unsold.where.not(id: @current_item.id).page(params[:page]).per(25) unless @current_item.nil?
    if params[:exclude_more_info].present?
      @current_item = nil;
    end
    respond_with @current_item
  end
  
  def search
    index = Algolia::Index.new("DoteItems")
    page_number = 0
    if params[:page].present?
      page_number = params[:page]
    end
    @item_ids = []
    
    negative_facet_filter = ""
    facet_filter = "("
    if !params[:store_id].present?
      current_user.user_favorite_stores.includes(:store).where(favorite: true).each do |favorite_store|
        if favorite_store.store.present? && favorite_store.store.name.present?
          facet_filter << "storeName:#{favorite_store.store.name},"
          negative_facet_filter << "storeName:-#{favorite_store.store.name},"
        end
      end
      facet_filter = facet_filter[0..-2]
      facet_filter << ")"
    else
      store = Store.find(params[:store_id])
      if store.present?
        facet_filter = "storeName:#{store.name}"
        negative_facet_filter = "storeName:-#{store.name}"
      end
    end
    max_number_of_items = 200
    filtered_search_result = index.search(params[:query],  { page:page_number, hitsPerPage:max_number_of_items, facetFilters:facet_filter, typoTolerance:"min" })
    filtered_search_result["hits"].each do |hit|
      @item_ids << hit["objectID"].to_i
    end
    item_ids_size = @item_ids.present? ? @item_ids.size : 0
    if (item_ids_size < max_number_of_items)
      search_result = index.search(params[:query],  { page:page_number, hitsPerPage:(max_number_of_items - item_ids_size), facetFilters:negative_facet_filter, typoTolerance:"min" })
      search_result["hits"].each do |hit|
        @item_ids << hit["objectID"].to_i
      end
    end
    @items = Item.includes(:store, :image, :category).where(id: @item_ids).active_and_unsold.uniq
  end
  
  def all_categories
    favorite_store_ids = (params[:favorite_store_ids].present? && !params[:favorite_store_ids].empty?) ? params[:favorite_store_ids] : current_user.favorite_store_ids
    @all_categories = Category.internal_for_overall.non_cj_sale.joins(sub_categories: {sub_categories: :items}).where(sub_categories_categories: { store_id: favorite_store_ids }).select(:name).uniq.map(&:name)
    sale_items_exist = Category.external.joins(:items).where("items.active = true AND items.sold_out = false AND items.msrp > items.price").where(store_id: favorite_store_ids).exists?
    if sale_items_exist
      @all_categories = ["SALE"] + @all_categories
    end
  end
end