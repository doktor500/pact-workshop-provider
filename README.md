### Provider Step 1 (Verifying an existing contract)

When we previously ran (in the consumer) the `spec/payment_service_client_spec.rb` test, it passed, but it also generated a `spec/pacts/paymentserviceclient-paymentservice.json` pact file that we can use to validate our assumptions in the provider side.

Pact has a rake task to verify the provider against the generated pact file. It can get the pact file from any URL (like the last successful CI build), but we are just going to use the local one for now.

Add to the `Rakefile` file the following line `require 'pact/tasks'` so it looks like this:

```ruby
require 'bundler'

Bundler.setup(:default, :development)

require 'pact/tasks'
```

Create `spec/pact_helper.rb` file with the following content

```ruby
require 'pact/provider/rspec'

Pact.service_provider "PaymentService" do
  honours_pact_with 'PaymentServiceClient' do
    pact_uri '../pact-workshop-consumer/spec/pacts/paymentserviceclient-paymentservice.json'
  end
end
```

In the `pact-workshop-provider` directory run `rake pact:verify`. You should see a failure because the consumer test does not validate the provider's current implementation.

Change the consumer test in the `pact-workshop-consumer` repository, so it references payment method `status` instead of payment method `state`. Generate the pact json file again by running `rspec`, and in the `pact-workshop-provider` repository execute the rake task `rake pact:verify` until the contract test becomes green.

When the test is fixed, in the `pact-workshop-consumer` directory run `git clean -df && git checkout . && git checkout consumer-step2`, also in the `pact-workshop-provider` directory run `git clean -df && git checkout . && git checkout provider-step2` and follow the instructions in the **Consumer's** readme file
