class ForeverWorker
  include Sidekiq::Worker
  include Sidekiq::Benchmark::Worker
  sidekiq_options :queue => :forever_crawler, :retry => false, :backtrace => true, :unique => true

  def perform
    benchmark do |bm|
      bm.forever_metric do
        Forever.store_items

        Sidekiq.logger.info "******************************************************"
        Sidekiq.logger.info "#{class_name} Update Complete"
        Sidekiq.logger.info "******************************************************"
      end
    end
  end
end