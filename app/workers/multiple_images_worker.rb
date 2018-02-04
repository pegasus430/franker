class MultipleImagesWorker
  include Sidekiq::Worker
  include Sidekiq::Benchmark::Worker
  sidekiq_options :queue => :multiple_images_crawler, :retry => true, :backtrace => true, :unique => true

  def perform(hash)
    benchmark do |bm|
      bm.multiple_images_metric do
        images = hash[:images]
        if images.present? && images.count > 0
          images.each do |image|
            @image = Image.new(imageable_type: hash[:type], imageable_id: hash[:item_id])
            @image.remote_file_url = image
            begin
              @image.save
              2.times { Curl.get(@image.file.url) }
            rescue Exception => e
              puts "^" * 40
              puts "Exception Occurred for Image Creation"
              puts "Item Details : #{item}"
              puts "Image Details : #{@image.inspect}"
              puts "Error: #{e}"
              puts "^" * 40
            end
            @image
          end
        end
      end
    end
  end
end