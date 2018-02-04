class ActiveRecord::Base

  def self.method_missing(method_id, *args, &block)
    method_name = method_id.to_s
    if method_name =~ /^update_or_create_by_(.+)$/
      update_or_create($1, *args, &block)
    else
      super
    end
  end

  def self.update_or_create(search, *args, &block)
    parameters = search.split("_and_")
    params = Hash[ parameters.zip(args) ]
    obj = where(params).first || self.new(params)
    yield obj
    obj.save
    obj
  end
end