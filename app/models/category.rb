class Category < ActiveRecord::Base

  has_many      :sub_categories, class_name: "Category", foreign_key: "parent_id"
  belongs_to    :store
  belongs_to    :parent, class_name: "Category", foreign_key: "parent_id"
  has_many      :items, dependent: :destroy

  scope :external, -> {where(category_type: "External")}
  scope :internal_for_store, -> {where(category_type: "Internal", overall_category: false)}
  scope :internal_for_overall, -> {where(category_type: "Internal", overall_category: true)}
  scope :sale, -> { where("special_tag = 'sale' OR name = 'SALE'") }
  scope :non_cj_sale, -> { where.not(name: "SALE") }
  scope :empty_special_tag, -> { non_cj_sale.where(special_tag: '') }
  scope :nil_special_tag, -> { non_cj_sale.where(special_tag: nil) }
  scope :non_sale, -> { empty_special_tag + nil_special_tag }
  scope :search_store, ->(store_id) { where(store_id: store_id) if store_id.present? }
  scope :search_sale, ->(sale1) { sale if sale1.present? }
  scope :search_non_sale, ->(non_sale1) { non_sale if non_sale1.present? }

  def self.get_external_categories
    self.includes(:sub_categories).map(&:sub_categories).flatten.uniq.map(&:sub_categories).flatten.uniq
  end

  def sale?
    special_tag == 'sale' || name == 'SALE'
  end

  def self.active_items(category_ids, sale)
    if category_ids.present? && category_ids.count > 0
      external_categories = Category.includes(:parent).where(parent_id: category_ids)
        
      # Remove internal categories
      if external_categories.any? && external_categories.first.category_type == 'Internal'
        external_categories = Category.includes(:parent).where(parent_id: external_categories.map(&:id))
      end

      if external_categories.any?
        if sale
          Item.where(category_id: external_categories.map(&:id).sample(external_categories.size)).active_unsold_and_on_sale
        else
          Item.where(category_id: external_categories.map(&:id).sample(external_categories.size)).active_and_unsold
        end
      else
        if sale
          Item.where(category_id: category_ids.sample(category_ids.size)).active_unsold_and_on_sale
        else
          Item.where(category_id: category_ids.sample(category_ids.size)).active_and_unsold
        end
      end
    else
      special_category_ids = Category.where(special: true).pluck(:id).compact
      if sale
        Item.active_unsold_and_on_sale.where.not(category_id: special_category_ids)
      else
        Item.active_and_unsold.where.not(category_id: special_category_ids)
      end
    end
  end
end