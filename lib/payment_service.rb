require "sinatra/base"
require "json"

require_relative "./payment_method_validator"

class PaymentService < Sinatra::Base
  get "/validate-payment-method/:payment_method", :provides => "json" do
    @payment_method_validator = PaymentMethodValidator.new
    JSON.pretty_generate({ :status => @payment_method_validator.validate(params[:payment_method]) })
  end
end
