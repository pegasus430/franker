class DeeplinkController < ApplicationController

  def specific_item
    @item = Item.find(params[:item_id])
    redirect_to @item.url
  end

  def itunes_link
    @itunes_url = "https://itunes.apple.com/in/app/dote-shopping-shop-womens/id908818458?mt=8"
    if params[:type] == "dote_picks" || params[:type] == "favorite_items"
      redirect_to @itunes_url
    end
  end

  def specific_store
    @store = Store.find(params[:store_id])
    redirect_to @store.url
  end
end