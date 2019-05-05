require "singleton"

class PaymentMethodRepository
  include Singleton

  def initialize
    reset
  end

  def reset
    @black_listed_payment_methods = []
  end

  def black_list(payment_method)
    @black_listed_payment_methods << payment_method
  end

  def is_black_listed?(payment_method)
    @black_listed_payment_methods.include?(payment_method)
  end
end
