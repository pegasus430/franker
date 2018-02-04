class Api::V1::CategoriesController < ApplicationController
  respond_to :json

  def get_categories
    @categories = Category.internal_for_store.includes(sub_categories: :items).where("store_id > ?", 11)
    respond_with @categories
  end

end