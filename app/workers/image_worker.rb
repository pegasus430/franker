class ImageWorker
  include Sidekiq::Worker
  include Sidekiq::Benchmark::Worker
  sidekiq_options :queue => :image_crawler, :retry => true, :backtrace => true, :unique => true

  def perform
    benchmark do |bm|
      bm.image_metric do
        10.times { puts  " "  }
        puts "--------Started Image caching----------"
        Image.where.not(file: nil).order(id: :desc).each do |image|
          if image.file.present?
            body = Curl.get(image.file.url).body
            puts "--------Image cached : #{image.file.url}----------"
          end
        end
        puts "-------- Image caching Ended ----------"
      end
    end
  end
end