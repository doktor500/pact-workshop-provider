require "payment_method_repository"
require "payment_method_validator"

RSpec.describe PaymentMethodValidator do
  let(:payment_method_repository) { PaymentMethodRepository.instance }
  let(:payment_method_validator) { PaymentMethodValidator.new }

  before(:each) do
    payment_method_repository.reset
  end

  it "validates payment method" do
    expect(payment_method_validator.validate("1234 1234 1234 1234")).to eq (:valid)
    expect(payment_method_validator.validate("1111 2222 3333 4444")).to eq (:valid)

    expect(payment_method_validator.validate("1111 2222 3333")).to eq (:invalid)
    expect(payment_method_validator.validate("1111 2222 3333 4444 5")).to eq (:invalid)
    expect(payment_method_validator.validate("1111 2222 3333 444A")).to eq (:invalid)
    expect(payment_method_validator.validate("")).to eq (:invalid)
    expect(payment_method_validator.validate(nil)).to eq (:invalid)
  end

  it "validates fraudulent payment method" do
    payment_method = "9999 9999 9999 9999"
    payment_method_repository.black_list(payment_method)

    expect(payment_method_validator.validate(payment_method)).to eq (:fraud)
  end
end
