### Provider Step 3 (Working with a PACT broker)

#### Verifying contracts with the pact-broker

In the `pact-workshop-provider` directory add `gem "pact_broker-client"` gem to the `Gemfile`, the file should look like:

```ruby
source 'https://rubygems.org'

gem 'rake'
gem 'sinatra'

group :development, :test do
  gem 'pact'
  gem 'pact_broker-client'
  gem 'rspec'
  gem 'rspec_junit_formatter'
end
```

In the `pact-workshop-provider` directory execute `bundle install`

Also in the `pact-workshop-provider` directory update the `pact_helper.rb` file with the following content in order to verify pacts in the broker.

```ruby
require 'pact/provider/rspec'

PUBLISH_VERIFICATION_RESULTS = ENV["PUBLISH_VERIFICATION_RESULTS"]
PACT_BROKER_BASE_URL         = ENV["PACT_BROKER_BASE_URL"] || "http://localhost:8000"
PACT_BROKER_TOKEN            = ENV["PACT_BROKER_TOKEN"]
CONSUMER_VERSION_TAG         = ENV["CONSUMER_VERSION_TAG"]

git_commit = `git rev-parse HEAD`.strip
git_branch = `git rev-parse --abbrev-ref HEAD`.strip

Pact.service_provider "PaymentService" do
  app_version git_commit
  app_version_tags [git_branch]
  publish_verification_results PUBLISH_VERIFICATION_RESULTS

  honours_pacts_from_pact_broker do
    pact_broker_base_url PACT_BROKER_BASE_URL, {token: PACT_BROKER_TOKEN}
    if (CONSUMER_VERSION_TAG) then
      consumer_version_tags [CONSUMER_VERSION_TAG]
    end
  end
end

Pact.provider_states_for "PaymentServiceClient" do
  provider_state "a black listed payment method" do
    set_up do
      invalid_payment_method = "9999999999999999"
      PaymentMethodRepository.instance.black_list(invalid_payment_method)
    end
  end
end
```

Now run `rake pact:verify`. You should see all tests passing. When we run this verification, we are using the contract that the consumer published to the broker.

If you run `PUBLISH_VERIFICATION_RESULTS=true rake pact:verify` and you navigate to your broker URL, you should see the contract verified.

In the `pact-workshop-consumer` directory run `git clean -df && git checkout . && git checkout consumer-step4` to continue with **Part II** of this workshop.
