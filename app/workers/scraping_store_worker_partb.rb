class ScrapingStoreWorkerPartb
  include Sidekiq::Worker
  sidekiq_options :queue => :crawler, :retry => false, :backtrace => true

  def perform
    Anthropologie.store_items
    Aritzia.store_items
    BrandyMelville.store_items
    sj = SidekiqJob.where(class_name: "SilentNotificationsWorker").last
    if sj.present? && ["completed", "failed"].include?(sj.status)
      SilentNotificationsWorker.perform_async
    end

  end
end