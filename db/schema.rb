# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150612181616) do

  create_table "addresses", force: true do |t|
    t.string   "full_name"
    t.string   "zipcode"
    t.text     "street_address"
    t.string   "apt_no"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "city"
    t.string   "state"
    t.string   "country",        default: "USA"
  end

  create_table "categories", force: true do |t|
    t.integer  "store_id"
    t.integer  "parent_id"
    t.boolean  "overall_category"
    t.string   "category_type"
    t.string   "name"
    t.text     "url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "special_tag"
    t.integer  "items_count"
    t.boolean  "special",          default: false
  end

  add_index "categories", ["category_type"], name: "index_categories_on_category_type", using: :btree
  add_index "categories", ["id", "parent_id", "store_id"], name: "index_categories_on_id_and_parent_id_and_store_id", using: :btree
  add_index "categories", ["parent_id"], name: "index_categories_on_parent_id", using: :btree
  add_index "categories", ["store_id"], name: "index_categories_on_store_id", using: :btree

  create_table "colors", force: true do |t|
    t.string   "name"
    t.string   "hash_value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "comments", force: true do |t|
    t.string   "message"
    t.integer  "item_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comments", ["created_at", "item_id", "user_id"], name: "index_comments_on_created_at_and_item_id_and_user_id", using: :btree

  create_table "dote_settings", force: true do |t|
    t.integer  "batch_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "image_id"
  end

  create_table "images", force: true do |t|
    t.string  "file_name"
    t.string  "content_type"
    t.string  "file_size"
    t.string  "file"
    t.integer "imageable_id"
    t.string  "imageable_type"
  end

  add_index "images", ["file"], name: "index_images_on_file", using: :btree
  add_index "images", ["imageable_id"], name: "index_images_on_imageable_id", using: :btree
  add_index "images", ["imageable_type"], name: "index_images_on_imageable_type", using: :btree

  create_table "item_colors", force: true do |t|
    t.string  "color"
    t.integer "item_id"
    t.integer "image_id"
    t.text    "url"
    t.string  "rgb"
    t.text    "sizes"
    t.string  "import_key"
    t.boolean "active",     default: true
    t.boolean "sold_out",   default: false
  end

  add_index "item_colors", ["image_id"], name: "index_item_colors_on_image_id", using: :btree
  add_index "item_colors", ["item_id"], name: "index_item_colors_on_item_id", using: :btree

  create_table "item_lists", force: true do |t|
    t.integer  "item_id"
    t.integer  "list_id"
    t.string   "quote"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "item_lists", ["id", "list_id", "item_id"], name: "index_item_lists_on_id_and_list_id_and_item_id", using: :btree
  add_index "item_lists", ["id"], name: "index_item_lists_on_id", using: :btree
  add_index "item_lists", ["item_id", "position"], name: "index_item_lists_on_item_id_and_position", using: :btree
  add_index "item_lists", ["item_id"], name: "index_item_lists_on_item_id", using: :btree
  add_index "item_lists", ["list_id"], name: "index_item_lists_on_list_id", using: :btree

  create_table "items", force: true do |t|
    t.string   "name"
    t.integer  "store_id"
    t.text     "url"
    t.integer  "price"
    t.integer  "msrp"
    t.string   "import_key"
    t.integer  "image_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "active",                              default: true
    t.boolean  "sold_out",                            default: false
    t.integer  "user_items_count",                    default: 0
    t.integer  "category_id"
    t.boolean  "new_one",                             default: false
    t.boolean  "trending",                            default: false
    t.string   "image_url"
    t.text     "description"
    t.text     "more_info",        limit: 2147483647
    t.text     "size"
  end

  add_index "items", ["active"], name: "index_items_on_active", using: :btree
  add_index "items", ["category_id"], name: "index_items_on_category_id", using: :btree
  add_index "items", ["created_at", "store_id"], name: "index_items_on_created_at_and_store_id", using: :btree
  add_index "items", ["import_key"], name: "index_items_on_import_key", using: :btree
  add_index "items", ["new_one"], name: "index_items_on_new_one", using: :btree
  add_index "items", ["sold_out"], name: "index_items_on_sold_out", using: :btree
  add_index "items", ["store_id", "import_key"], name: "index_items_on_store_id_and_import_key", using: :btree
  add_index "items", ["store_id"], name: "index_items_on_store_id", using: :btree

  create_table "lists", force: true do |t|
    t.string   "name"
    t.string   "cover_image"
    t.string   "content_square_image"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "designer_name"
    t.string   "designer_url"
    t.boolean  "active",               default: true
  end

  add_index "lists", ["active", "id", "created_at"], name: "index_lists_on_active_and_id_and_created_at", using: :btree

  create_table "notifications", force: true do |t|
    t.text    "message"
    t.integer "priority"
    t.string  "notification_type"
    t.boolean "seen"
    t.text    "custom_data"
    t.integer "user_id"
  end

  add_index "notifications", ["user_id"], name: "index_notifications_on_user_id", using: :btree

  create_table "order_items", force: true do |t|
    t.integer  "item_id"
    t.integer  "order_id"
    t.integer  "quantity"
    t.text     "item_data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "size"
    t.string   "color"
    t.integer  "store_id"
    t.datetime "confirmed_at"
    t.datetime "shipped_at"
  end

  add_index "order_items", ["order_id"], name: "index_order_items_on_order_id", using: :btree

  create_table "orders", force: true do |t|
    t.string   "transaction_id"
    t.string   "customer_id"
    t.integer  "user_id"
    t.integer  "total_amount"
    t.integer  "item_amount"
    t.integer  "sales_tax_amount"
    t.integer  "status",            default: 0
    t.integer  "address_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "errors_hash"
    t.integer  "shipping_price"
    t.integer  "retailer_order_id", default: 0
  end

  add_index "orders", ["status"], name: "index_orders_on_status", using: :btree
  add_index "orders", ["user_id"], name: "index_orders_on_user_id", using: :btree

  create_table "retailer_orders", force: true do |t|
    t.string   "confirmation_number"
    t.string   "tracking_number"
    t.string   "tracking_url"
    t.text     "notes"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sales_taxes", force: true do |t|
    t.string "zipcode"
    t.float  "percentage", limit: 24
    t.string "state_code"
  end

  add_index "sales_taxes", ["zipcode"], name: "index_sales_taxes_on_zipcode", using: :btree

  create_table "settings", force: true do |t|
    t.string "key"
    t.string "value"
  end

  create_table "sidekiq_jobs", force: true do |t|
    t.string   "jid"
    t.string   "queue"
    t.string   "class_name"
    t.text     "args"
    t.boolean  "retry"
    t.datetime "enqueued_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "status"
    t.string   "name"
    t.text     "result"
  end

  add_index "sidekiq_jobs", ["class_name"], name: "index_sidekiq_jobs_on_class_name", using: :btree
  add_index "sidekiq_jobs", ["enqueued_at"], name: "index_sidekiq_jobs_on_enqueued_at", using: :btree
  add_index "sidekiq_jobs", ["finished_at"], name: "index_sidekiq_jobs_on_finished_at", using: :btree
  add_index "sidekiq_jobs", ["jid"], name: "index_sidekiq_jobs_on_jid", using: :btree
  add_index "sidekiq_jobs", ["queue"], name: "index_sidekiq_jobs_on_queue", using: :btree
  add_index "sidekiq_jobs", ["retry"], name: "index_sidekiq_jobs_on_retry", using: :btree
  add_index "sidekiq_jobs", ["started_at"], name: "index_sidekiq_jobs_on_started_at", using: :btree
  add_index "sidekiq_jobs", ["status"], name: "index_sidekiq_jobs_on_status", using: :btree

  create_table "stores", force: true do |t|
    t.string   "name"
    t.string   "url"
    t.integer  "image_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position",             default: 1
    t.boolean  "payment",              default: false
    t.boolean  "active",               default: true
    t.boolean  "more_info",            default: false
    t.integer  "shipping_price"
    t.integer  "min_threshold_amount"
    t.integer  "items_count",          default: 0,                     null: false
    t.string   "logo_icon"
    t.string   "square_logo_icon"
    t.string   "circle_logo_icon"
    t.datetime "activation_date"
    t.datetime "items_updated_at",     default: '2015-03-10 18:11:47'
    t.string   "affiliate_link"
  end

  add_index "stores", ["active"], name: "index_stores_on_active", using: :btree
  add_index "stores", ["created_at", "active"], name: "index_stores_on_created_at_and_active", using: :btree

  create_table "user2_items", force: true do |t|
    t.integer "user_id"
    t.integer "item_id"
    t.boolean "favorite"
    t.boolean "sale"
  end

  add_index "user2_items", ["item_id", "user_id", "favorite"], name: "index_user2_items_on_item_id_and_user_id_and_favorite", using: :btree
  add_index "user2_items", ["item_id", "user_id"], name: "index_user2_items_on_item_id_and_user_id", unique: true, using: :btree

  create_table "user_favorite_stores", force: true do |t|
    t.integer  "user_id"
    t.integer  "store_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position",   default: 0
    t.boolean  "favorite"
  end

  add_index "user_favorite_stores", ["user_id"], name: "index_user_favorite_stores_on_user_id", using: :btree

  create_table "user_items", force: true do |t|
    t.integer  "user_id"
    t.integer  "item_id"
    t.boolean  "favorite"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "sale",       default: false
  end

  add_index "user_items", ["user_id", "item_id", "favorite"], name: "index_user_items_user_id_item_id_favorite", using: :btree
  add_index "user_items", ["user_id", "item_id"], name: "index_user_items_on_user_id_item_id", unique: true, using: :btree

  create_table "user_lists", force: true do |t|
    t.integer  "user_id"
    t.integer  "list_id"
    t.datetime "seen_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "user_lists", ["user_id"], name: "index_user_lists_on_user_id", using: :btree

  create_table "users", force: true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "uuid"
    t.string   "imei"
    t.datetime "last_activity_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "dev_token"
    t.boolean  "force_upgrade"
    t.string   "appstore_url"
    t.string   "timezone"
    t.text     "payment_method_data"
    t.integer  "address_id"
  end

  add_index "users", ["imei"], name: "index_users_on_imei", using: :btree
  add_index "users", ["uuid"], name: "index_users_on_uuid", using: :btree

end
