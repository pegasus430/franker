class ScrapingStoreWorkerParta
  include Sidekiq::Worker
  sidekiq_options :queue => :crawler, :retry => false, :backtrace => true

  def perform
    Madewell.store_items
    Jcrew.store_items
    Lululemon.store_items
  end
end