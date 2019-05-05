require_relative "./payment_method_repository"

class PaymentMethodValidator
  def initialize(payment_method_repository = PaymentMethodRepository.instance)
    @payment_method_repository = payment_method_repository
  end

  def validate(payment_method)
    return :fraud if @payment_method_repository.is_black_listed?(payment_method)
    if is_valid?(payment_method) then :valid else :invalid end
  end

  private

  def is_valid?(payment_method)
    /\d{16}/.match(payment_method&.split&.join)
  end
end
