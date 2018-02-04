require "csv"
store_data = [{name: "J Crew", url: Store::JCREW},
              {name: "Madewell", url: Store::MADEWELL},
              {name: "Anthropologie", url: Store::ANTHROPOLOGIE},
              {name: "lululemon", url: Store::LULULEMON},
              {name: "Aritzia", url: Store::ARITZIA},
              {name: "Brandy Melville", url: Store::BRANDYMELVILLE},
              {name: "Abercrombie", url: Store::ABERCROMBIE},
              {name: "Zara", url: Store::ZARA},
              {name: "Gap", url: ""},
              {name: "American Apparel", url: ""},
              {name: "Vineyard Vines", url: ""},
              {name: "H&M", url: ""},
              {name: "Hollister", url: ""},
              {name: "American Eagle", url: ""},
              {name: "Pink", url: ""},
              {name: "Victoria Secret", url: ""},
              {name: "Kate Spade", url: ""},
              {name: "Nike", url: ""},
              {name: "Bauble Bar", url: ""},
              {name: "Charlotte Russe", url: ""},
              {name: "Hot Topic", url: ""},
              {name: "Wet Seal", url: ""},
              {name: "C Wonder", url: ""},
              {name: "Nasty Gal", url: ""},
              {name: "Wildfox", url: ""},
              {name: "Lilly Pulitzer", url: ""},
              {name: "Aldo", url: ""},
              {name: "Tory Burch", url: ""},
              {name: "Rue 21", url: ""},
              {name: "Tilly's", url: nil}]
store_data.each do |store|
  @store = Store.where(store).last
  @store ||= Store.new(store)
  unless @store.persisted?
    @image = Image.new(file: File.open("app/assets/images/#{@store.name.downcase.split(' ').join('_')}.png"))
    @image.content_type = MIME::Types.type_for(@image.file.url).first.content_type
    @image.file_name = File.basename(@image.file.url)
    @image.file_size = @image.file.size
    @image.save!
    @store.image = @image
    @store.save!
  end
end
Store.find_or_create_by(name: "Free People")
Store.find_or_create_by(name: "Urban Outfitters")
Store.find_or_create_by(name: "Banana Republic")
Store.find_or_create_by(name: "Forever 21")
Store.find_or_create_by(name: "Topshop")
# Store.find_or_create_by(name: "Nike")
# Store.find_or_create_by(name: "Sephora")
# Store.find_or_create_by(name: "Vineyard Vines")
["All Saints", "Steve Madden", "River Island", "Toms", "Charming Charlie", "ASOS"].each do |name|
  @store = Store.where(name: name).last
  @store ||= Store.new(name: name)
  unless @store.persisted?
    @image = Image.new(file: File.open("app/assets/images/#{@store.name.downcase.split(' ').join('_')}.png"))
    @image.content_type = MIME::Types.type_for(@image.file.url).first.content_type
    @image.file_name = File.basename(@image.file.url)
    @image.file_size = @image.file.size
    @image.save!
    @store.image = @image
    @store.save!
  end
end
# Newly added
cj_store_data = [{name: "Garage Clothing"},
                 {name: "Loft"},
                 {name: "Pacsun"},
                 {name: "Ann Taylor"},
                 {name: "Athleta"},
                 {name: "Shopbop"},
                 {name: "Tilly's"},
                 {name: "Sheinside"}]

cj_store_data.each do |store|
  @store = Store.where(store).last
  @store ||= Store.new(store)
  unless @store.persisted?
    @image = Image.new(file: File.open("app/assets/images/#{@store.name.downcase.split(' ').join('_')}.png"))
    @image.content_type = MIME::Types.type_for(@image.file.url).first.content_type
    @image.file_name = File.basename(@image.file.url)
    @image.file_size = @image.file.size
    @image.save!
    @store.image = @image
    @store.save!
  end
end

# Store.find_or_create_by(name: "Garage Clothing")
# Store.find_or_create_by(name: "Loft")
# Store.find_or_create_by(name: "Pacsun")
# Store.find_or_create_by(name: "Ann Taylor")

@admin = User.find_by_email("test@crypsis.net")
@admin ||= User.create(email: "test@crypsis.net", password: "password", password_confirmation: "password", imei: "12312")
CSV.read("db/data/Categories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @internal_category_for_overall = Category.find_or_create_by(name: row[:InternalCategoryForOverall], overall_category: true, category_type: "Internal")
  @internal_category_for_store = Category.find_or_create_by(store_id: @store.id, name: row[:InternalCategoryByStore], parent_id: @internal_category_for_overall.id, overall_category: false, category_type: "Internal")
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External").last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], parent_id: @internal_category_for_store.id)    
  @sub_category.save!
  if @store.name == 'J Crew'
    @sub_category.update_attribute(:url, row[:URL])
  end
end

CSV.read("db/data/BrandyMelvilleCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External").last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL])
  @sub_category.save!
end
CSV.read("db/data/ZaraCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External").last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL])
  @sub_category.save!
end
CSV.read("db/data/AbercrombieCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External").last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL])
  @sub_category.save!
end

CSV.read("db/data/GapCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end


CSV.read("db/data/AmericanApparelCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

# Vineyard Vines
CSV.read("db/data/VineyardVinesCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end


# EBAY https://www.pepperjamnetwork.com
#"Charlotte Russe", "Bauble Bar" - Need to do scraping
["Aeropostale", "Juicy Couture"].each do |store_name|
  store = Store.find_or_initialize_by(name: store_name)
  unless store.persisted?
    image = Image.new(file: File.open("app/assets/images/#{store.name.downcase.split(' ').join('_')}.png"))
    image.content_type = MIME::Types.type_for(image.file.url).first.content_type
    image.file_name = File.basename(image.file.url)
    image.file_size = image.file.size
    image.save!
    if image.persisted?
      store.image_id = image.id
      store.save!
    end
  end
end


# Performance Test for Development
# 100.times {|i| User.create(imei: "9DFC0C9B-9E38-4660-B5D2-97BB1A84ED8#{i}")}
data = []
conn = ActiveRecord::Base.connection
CSV.read("db/data/Zipcodes.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  value = row[:CombinedRate].to_f * 100
  data.push("('#{row[:ZipCode]}', '#{value.round(4)}', '#{row[:State]}')")
  # @sales_tax = SalesTax.find_or_create_by(zipcode: row[:ZipCode], percentage: value.round(4), state_code: row[:State])
end
conn.execute("INSERT INTO sales_taxes (`zipcode`, `percentage`, `state_code`) VALUES #{data.join(', ')}")

CSV.read("db/data/H_MCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

CSV.read("db/data/HollisterCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

CSV.read("db/data/AmericanEagleCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

CSV.read("db/data/PinkCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

CSV.read("db/data/VictoriaSecretCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end


CSV.read("db/data/KateSpadeCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

CSV.read("db/data/NikeCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

Category.external.select {|c| c.destroy if (!c.name.downcase.include?("womens")) && (c.name.downcase.include?("mens") || c.name.downcase.include?("boys")) }
Item.all.select {|c| c.destroy if (!c.name.downcase.include?("womens")) && (c.name.downcase.include?("mens") || c.name.downcase.include?("boys")) }


CSV.read("db/data/CharlotteRusseCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

CSV.read("db/data/BaubleBarCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end
DoteSettings.create
Store.find_by(name: "Banana Republic").items.each {|i| i.update(name: i.name.split("Banana Republic ").last.strip) }
Store.find_by(name: "Free People").items.each {|i| i.update(name: i.name.split("Free People ").last.strip) }
Store.find_by(name: "All Saints").items.each {|i| i.update(name: i.name.split("All Saints ").last.strip) }

CSV.read("db/data/HotTopicCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

anthro_color_names = Store.find(3).items.active_and_unsold.includes(:item_colors).flat_map(&:item_colors).flat_map(&:color).compact.uniq
anthro_color_names.each {|n| Color.find_or_create_by(name: n.downcase) }
OrderItem.all.each {|i| i.update(store_id: i.item.store_id)}
# New stores
["db/data/WildfoxCategories.csv", "db/data/CWonderCategories.csv", "db/data/LillyPulitzerCategories.csv", "db/data/NastyGalCategories.csv", "db/data/WetSealCategories.csv", "db/data/AldoCategories.csv"].each do |csv_path|
  CSV.read(csv_path, :headers => true).each_with_index do |line, i|
    row = line.to_hash.symbolize_keys!
    @store = Store.where(name: row[:StoreName]).last
    @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
    @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
    @sub_category.save!
  end
end

# Need to scrape CWONDER, WetSeal



# For updating import_keys for anthropologie

Store.find(3).items.each do |item|
  if item.item_colors && item.item_colors.count > 0
    item.item_colors.each do |i|
      if i.color.present?
        i.update(import_key: "#{i.item.store.name.downcase.split(" ").join("_")}_#{i.item_id}_#{i.color.downcase.split(" ").join("_")}")
      else
        i.update(import_key: "#{i.item.store.name.downcase.split(" ").join("_")}_#{i.item_id}_#{i.image_id}")
      end
    end
  end
end


# Default Dote Picks Icon Seed.
# @image = Image.new(file: File.open("app/assets/images/DotePicksButton.png"))
# @image.content_type = MIME::Types.type_for(@image.file.url).first.content_type
# @image.file_name = File.basename(@image.file.url)
# @image.file_size = @image.file.size
# @image.save!


# Script for Seeding Dev Database into Local DB
#
# unless Rails.env.production?
#   connection = ActiveRecord::Base.connection
#   connection.tables.each do |table|
#     connection.execute("TRUNCATE #{table}") unless table == "schema_migrations"
#   end

#   # - IMPORTANT: SEED DATA ONLY
#   # - DO NOT EXPORT TABLE STRUCTURES
#   # - DO NOT EXPORT DATA FROM `schema_migrations`
#   sql = File.read('db/dote_dev.sql')
#   statements = sql.split(/;$/)
#   statements.pop  # the last empty statement

#   ActiveRecord::Base.transaction do
#     statements.each do |statement|
#       connection.execute(statement)
#     end
#   end
# end
["db/data/ToryBurchCategories.csv", "db/data/Rue21Categories.csv", "db/data/TillysCategories.csv"].each do |csv_path|
  CSV.read(csv_path, :headers => true).each_with_index do |line, i|
    row = line.to_hash.symbolize_keys!
    @store = Store.where(name: row[:StoreName]).last
    @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
    @sub_category ||= Category.new
    #@sub_category.store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
    {"store_id" => @store.id, "name" => row[:ExternalCategory], "category_type" => "External", "overall_category" => false, "url" => row[:URL], "special_tag" => row[:special_tag]}.each do |k,v|
      @sub_category.send("#{k}=", v)	    
    end
    @sub_category.save!
  end
end

CSV.read("db/data/AsosCategories.csv", :headers => true).each_with_index do |line, i|
  row = line.to_hash.symbolize_keys!
  @store = Store.where(name: row[:StoreName]).last  
  @sub_category = Category.where(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

@adidas_store = Store.find_or_create_by(name: "Adidas")
CSV.read("db/data/AdidasCategories.csv", :headers => true).each_with_index do |line, i|    
  row = line.to_hash.symbolize_keys!
  @sub_category = Category.where(store_id: @adidas_store.id, name: row[:ExternalCategory], category_type: "External", special_tag: row[:special_tag]).last
  @sub_category ||= Category.new(store_id: @adidas_store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end

@ivivva_store = Store.find_or_create_by(name: "Ivivva")
CSV.read("db/data/IvivvaCategories.csv", :headers => true).each_with_index do |line, i|    
  row = line.to_hash.symbolize_keys!
  @sub_category = Category.where(store_id: @ivivva_store.id, name: row[:ExternalCategory], category_type: "External").last
  @sub_category ||= Category.new(store_id: @ivivva_store.id, name: row[:ExternalCategory], category_type: "External", overall_category: false, url: row[:URL], special_tag: row[:special_tag])
  @sub_category.save!
end
