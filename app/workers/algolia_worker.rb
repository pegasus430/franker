require 'algoliasearch'
Algolia.init :application_id => "ZYNHDLTA0N", :api_key => "4cc83654495c33dfed1635560609749b"

class AlgoliaWorker

  def self.add_item_to_algolia(item)
    if Rails.env.production? && item.present?
      index = Algolia::Index.new("DoteItems")
      begin
        index.save_object(hash_for_item(item))
      rescue Exception => e
        puts "---------- Algolia adding item error ----------"
        puts "Exception: #{e}"
        puts "---------- Algolia adding item Ends ----------"
      end

    end
  end

  def self.delete_item_from_algolia(item)
    if Rails.env.production? && item.present?
      index = Algolia::Index.new("DoteItems")

      begin
        index.delete_object(item.id)
      rescue Exception => e
        puts "---------- Algolia deleting item error ----------"
        puts "Exception: #{e}"
        puts "---------- Algolia deleting item Ends ----------"
      end

    end
  end

  def self.load_all_items_to_algolia
    index = Algolia::Index.new("DoteItems")

    all_items = Item.active_and_unsold
    puts "#{all_items.size} items will be sent to algolia"

    i = 0
    records = []
    all_items.each do |item|
      records << hash_for_item(item)
      i += 1
      if (i % 100 == 0)
        puts "#{i} item dictionaries created"
      end
      if (i % 1000 == 0)
        puts "Sending 1000 records to algolia"
        index.add_objects(records)
        records = []
      end
    end
    index.add_objects(records)
  end

  private
  def self.hash_for_item(item)
    itemDict = Hash.new()
    itemDict["objectID"] = item.id
    itemDict["itemName"] = item.name
    itemDict["itemDescription"] = item.description
    if item.store.present?
      itemDict["storeName"] = item.store.name
    end
    if item.category.present? && item.category.parent.present?
      itemDict["category"] = item.category.parent.name
    end
    colors = []
    item.item_colors.each { |color_info|
      colors << color_info.color
    }
    itemDict["colors"] = colors
    itemDict
  end

end