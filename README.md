### Provider Step 6 (Implement and deploy a new feature)

In previous steps, the consumer implemented in a feature branch a new feature that it is not yet supported by the provider. In this step, we are going to implement the necessary changes in the provider to support the feature and we are going to deploy it to production, so the consumer can deploy the feature branch as soon as the latest version of the provider is released.

We want now to support credit card numbers that have length 15. So let's start by adding a new test case that exercises this new behavior.

Change the `payment_method_validator_spec.rb` file so it looks like:

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
    expect(payment_method_validator.validate("1234 1234 1234 1234")).to eq (:valid)
    expect(payment_method_validator.validate("1111 2222 3333 4444")).to eq (:valid)
    expect(payment_method_validator.validate("1111 2222 3333 444")).to eq (:valid)
  end

  it "validates invalid payment methods" do
    expect(payment_method_validator.validate("1111 2222 3333")).to eq (:invalid)
    expect(payment_method_validator.validate("1111 2222 3333 444A")).to eq (:invalid)
    expect(payment_method_validator.validate("")).to eq (:invalid)
    expect(payment_method_validator.validate(nil)).to eq (:invalid)
  end

  it "validates a fraudulent payment method" do
    payment_method = "9999 9999 9999 9999"
    payment_method_repository.black_list(payment_method)

    expect(payment_method_validator.validate(payment_method)).to eq (:fraud)
  end
end
```

As you can see, we added the third test case for valid payment methods in where the credit card number has length 15, if you run the test with `rspec`, you should see it failing, since the current implementation does not support this case yet.

If we edit the `payment_method_validator.rb` file and we add an implementation like the following one, it will make all the tests green.

```ruby
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
```

Open a pull request for this branch after a while it will become green.

These are the steps that will happen when you open the PR.

- The unit tests will run
- The verification step is run against the contracts tagged with the `production` tag for all the consumers (we currently have only one consumer)
- Since this version of the provider is compatible with all the consumers tagged with the `production` tag, the can-i-deploy check succeeds.

Merge the PR to master branch.

- This version of the provider will be deployed to production and this version of the contract is tagged with the `production` tag.
- The verification step is run and the results are published to the broker.
- The hook for the feature branch in the consumer side is triggered, and at this stage.
- At this stage the consumer knows that the provider that supports the new feature has been released to production

Navigate to the directory in where you checked out `pact-workshop-consumer`, run `git clean -df && git checkout . && git checkout consumer-step7` if you haven't already done so and follow the instructions in the **Consumers's** readme file
