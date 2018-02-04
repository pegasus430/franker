require "net/ftp"
class AllSaints < LinkShare

  ADVERTISER_ID = "37190"

  class << self
    def store_items
      # name --> Class name
      @store = Store.find_by(name: "All Saints")
      name = @store.name.split(' ').join('').downcase
      if File.exists?("db/data/#{name.downcase}.xml") && File.mtime("db/data/#{name.downcase}.xml").to_date == Date.today
        extract_xml(@store.name)
      else
        gz_file = download_zip_files_via_ftp(name, AllSaints::ADVERTISER_ID)
        xml_file = unzip_gz_files(@store.name) if gz_file
        extract_xml(@store.name) if xml_file
      end
    end
  end
end