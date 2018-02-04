class MoreInfoWorkerSlow
  include Sidekiq::Worker
  include Sidekiq::Benchmark::Worker
  sidekiq_options :queue => :more_info_slow, :retry => false, :backtrace => true

  def perform(class_name_to_metric_hash)
    benchmark do |bm|
      class_name_to_metric_hash.each do |class_name, metric_name|
        bm.send(metric_name) do
          store_class = class_name.constantize
          store_class.store_items

          Sidekiq.logger.info "******************************************************"
          Sidekiq.logger.info "#{class_name} Update Complete"
          Sidekiq.logger.info "******************************************************"
        end
      end

      bm.image_items_metric do
        Image.where(file: nil).delete_all
        Item.where(image_id: nil).update_all(active: false)
        Item.active.find_each {|i| i.update(active: false) unless i.image.present? }
      end
    end
  end
end