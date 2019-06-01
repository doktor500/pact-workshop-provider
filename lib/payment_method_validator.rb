require_relative "./payment_method_repository"

class PaymentMethodValidator
  MIN_PAYMENT_METHOD_LENGTH = 15
  MAX_PAYMENT_METHOD_LENGTH = 16

  def initialize(payment_method_repository = PaymentMethodRepository.instance)
    @payment_method_repository = payment_method_repository
  end

  def validate(payment_method)
    return :fraud if @payment_method_repository.is_black_listed?(payment_method)
    if is_valid?(sanitize(payment_method)) then :valid else :invalid end
  end

  private

  def is_valid?(payment_method)
    valid_length = payment_method&.length&.between?(MIN_PAYMENT_METHOD_LENGTH, MAX_PAYMENT_METHOD_LENGTH)
    valid_format = /\d{#{payment_method&.length}}/.match(payment_method)
    valid_length && valid_format
  end

  def sanitize(payment_method)
    payment_method&.split&.join
  end
end
