class Redis
  def cached_list(key, params={})


    # Rails.logger.debug("Redis#cached_list: key : #{key}, params : #{params.inspect}")

    size = params[:size] || 10
    expire = params[:expire] || 1.hour
    data = lrange(key, 0, size-1)

    if data.present? # && data.size == size
      ltrim(key, size, -1)
      return data.map{|d| Marshal.load(d) }
    end

    data = yield

    del(key)
    if data[size..-1].present?
      data[size..-1].each do |datum|
        rpush(key, Marshal.dump(datum))
      end
    end
    expire(key, expire) if expire
    return data[0...size]
  end

  def cached(key, params={})
    data = get(key)
    expire = params[:expire] || 1.hour

    if data
      return Marshal.load(data)
    end

    data = yield

    set(key, Marshal.dump(data))
    expire(key, expire) if expire

    return data
  end

end