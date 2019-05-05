### Provider Step 7 (Introduce incompatible changes with consumers in production)

Now let's see what it would happen if we want to change the API in the provider so that it returns responses that contain "accepted/rejected" status values instead of "valid/invalid".

Start changing the `payment_method_validator_spec.rb` file so it looks like:

```ruby
require "payment_method_repository"
require "payment_method_validator"

RSpec.describe PaymentMethodValidator do
  let(:payment_method_repository) { PaymentMethodRepository.instance }
  let(:payment_method_validator) { PaymentMethodValidator.new }

  before(:each) do
    payment_method_repository.reset
  end

  it "validates valid payment methods" do
    expect(payment_method_validator.validate("1234 1234 1234 1234")).to eq (:accepted)
    expect(payment_method_validator.validate("1111 2222 3333 4444")).to eq (:accepted)
    expect(payment_method_validator.validate("1111 2222 3333 444")).to eq (:accepted)
  end

  it "validates invalid payment methods" do
    expect(payment_method_validator.validate("1111 2222 3333")).to eq (:rejected)
    expect(payment_method_validator.validate("1111 2222 3333 444A")).to eq (:rejected)
    expect(payment_method_validator.validate("")).to eq (:rejected)
    expect(payment_method_validator.validate(nil)).to eq (:rejected)
  end

  it "validates a fraudulent payment method" do
    payment_method = "9999 9999 9999 9999"
    payment_method_repository.black_list(payment_method)

    expect(payment_method_validator.validate(payment_method)).to eq (:fraud)
  end
end
```

Run the tests with `rspec`, the test should fail, modify `validate` method in the `payment_method_validator.rb` file so it looks like:

```ruby
def validate(payment_method)
  return :fraud if @payment_method_repository.is_black_listed?(payment_method)
  if is_valid?(sanitize(payment_method)) then :accepted else :rejected end
end
```

Run the tests again with `rspec`, it should be green now.

Create a new commit that includes all the changes, push them to GitHub and see what happens.

The feature branch build should fail because the `can-i-deploy` step should tell you that this branch is not compatible with the current consumers deployed in production.

If you want to make this change in the API, you can implement two different versions of the API that work at the same time. V1 will continue using "valid/invalid" values while V2 will use "accepted/rejected".

At this stage, we can deploy the provider to production, and start the migration of consumers to the provider's V2 API. Once all of the consumers are using V2, you can safely deprecate V1 of this API, because you will know that there are no consumers using it.

We will leave this exercise to you so that you can explore the advantages of this setup.
