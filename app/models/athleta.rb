class Athleta < Gap
  DOMAIN = "athleta.gap.com"
  API_URL = "http://#{self::DOMAIN}/resources/productSearch/v1/search?cid=%%cid%%&style=%%style%%"
  PRODUCT_URL = "http://#{self::DOMAIN}/browse/product.do?cid=%%child_cid%%&pid=%%PID%%"
  PRODUCT_RESOURCE_URL = "http://#{self::DOMAIN}/browse/productData.do?pid=%%pid%%&vid=1&scid=&actFltr=false&locale=en_US&internationalShippingCurrencyCode=&internationalShippingCountryCode=us&globalShippingCountryCode=us"  
  IMPORT_KEY_PREFIX = "athleta_"
  STORE_NAME = "Athleta"  
end