class ItemsSoldOutWorker
  include Sidekiq::Worker
  include Sidekiq::Benchmark::Worker
  sidekiq_options :queue => :items_sold_out_crawler, :retry => false, :backtrace => true, :unique => true

  def perform(class_name_to_metric_hash)
    benchmark do |bm|
      class_name_to_metric_hash.each do |class_name, metric_name|
        bm.send(metric_name) do
          store_class = class_name.constantize
          store_class.store_items(true)

          Sidekiq.logger.info "******************************************************"
          Sidekiq.logger.info "#{class_name} Update Complete"
          Sidekiq.logger.info "******************************************************"
        end
      end
    end
  end
end