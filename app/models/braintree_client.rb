class BraintreeClient < ActiveRecord::Base

  def self.generate_token
    @client_token = Braintree::ClientToken.generate
  end
end