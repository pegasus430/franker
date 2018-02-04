class Toms < LinkShare

  ADVERTISER_ID = "38583"

  class << self
    def store_items
      @store = Store.find_by(name: "Toms")
      name = @store.name.split(' ').join('').downcase
      if File.exists?("db/data/#{name.downcase}.xml") && File.mtime("db/data/#{name.downcase}.xml").to_date == Date.today
        extract_xml(name)
      else
        gz_file = download_zip_files_via_ftp(name, ADVERTISER_ID)
        xml_file = unzip_gz_files(name) if gz_file
        extract_xml(name) if xml_file
      end
    end
  end
end