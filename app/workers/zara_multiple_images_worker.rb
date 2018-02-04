class ZaraMultipleImagesWorker
  include Sidekiq::Worker
  include Sidekiq::Benchmark::Worker
  sidekiq_options :queue => :zara_multiple_images_crawler, :retry => true, :backtrace => true, :unique => true

  def perform(hash)
    benchmark do |bm|
      bm.multiple_images_metric do
        images = hash[:images]
        if images.present? && images.count > 0
          images.each do |image|
            begin
              tf = MiniMagick::Image.read(open(image, "User-Agent" => "DoteBot").read)
              @image = Image.new(file: tf, imageable_type: type, imageable_id: item.id)
            rescue Exception => e
              puts "^" * 40
              puts "Exception Occurred for MiniMagick Multiple Images"
              puts "URL : #{image}"
              puts "Image Details : #{@image.inspect}"
              puts "Error: #{e}"
              puts "^" * 40
              @image.destroy
            end
            if @image.present?
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
            else
              next
            end
          end
        end
      end
    end
  end
end