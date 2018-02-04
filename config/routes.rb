require 'sidekiq/web'
require "api_constraints"

DoteWeb::Application.routes.draw do

  devise_for :users

  get "/item_id=:item_id" => "deeplink#specific_item"
  get "/type=:type/list_id=:list_id" => "deeplink#itunes_link"
  get "/type=:type" => "deeplink#itunes_link"
  get "/store_id=:store_id/type=:type" => "deeplink#specific_store"
  get "/store_id=:store_id" => "deeplink#specific_store"
  get "/store_id=:store_id/item_id=:item_id" => "deeplink#specific_item"
  namespace :api, defaults: {format: 'json' } do
    scope module: :v1, constraints: ApiConstraints.new(version: 1, default: true) do
      resources :stores do
        post "favorite"
        post "update_position"
        delete "favorite"
        collection do
          get "favorites"
          get "get_stores"
          get "new_item_count"
        end
      end
      resources :categories do
        collection do
          get "get_categories"
        end
      end
      resources :lists do
        post "create_user_list"
      end
      resources :items do
        post "favorite"
        post "seen"
        delete "favorite"
        collection do
          get "favorites"
          get "more_info"
          get "search"
          get "all_categories"
        end
        resources :comments
      end
      get "/force_upgrade" => "users#force_upgrade"
      resources :orders
      resources :users do
        member do
          get "show"
          put "make_notifications_seen"
          get "braintree_client_token"
          get "default_payment_method"
          post "create_payment"
          post "update_payment_details"
          get 'get_detail_of_card'
          get 'find_sales_tax'
        end
        collection do
          post 'register'
          get 'get_users'
        end
      end
    end
  end

  namespace :admin do
    root "stores#index"
    resources :addresses do
    end
    resources :colors
#    get 'settings' => 'users#settings'
    put 'update_settings' => 'users#update_settings'
    resources :users do
      get 'deletion'
      collection do
        post 'destroy_individual'
      end
    end
    resources :orders do
      post "submit_for_settlement"
      post "void"
      post "sold_out"
      get "transaction_payment_method"
    end
    resources :order_items do
    end
    resources :retailer_orders do
      post "submit_for_settlement_and_email_shipping_confirmation"
      post "email_confirmation"
    end
    resources :lists do
      post 'create_item_lists'
      delete 'destroy_item_list'
      get 'edit_item_list'
      post "update_item_list"
      post "activate"
      post "deactivate"
      collection do
        put 'dote_picks_icon'
      end
    end
    resources :stores do
        post "activate"
        post "deactivate"
        delete "trending"
      resources :items do
        post "activate"
        post "deactivate"
        post "trending"
        delete "trending"
        post "add_lists"
      end
    end
    resources :categories do
      collection do
        get "filter_by_store"
      end
    end
    resources :settings do
        collection do
            put 'update_settings'
        end
    end
    authenticate :user do
      mount Sidekiq::Web => '/sidekiq'
      mount Sidekiq::Monitor::Engine => '/sidekiq-monitoring'
    end
  end

  root "admin/stores#index"
end
