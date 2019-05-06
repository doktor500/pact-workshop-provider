### Requirements

- Ruby 2.4.4 (It is already installed if you are using Mac OS X)
- [Docker](https://hub.docker.com/editions/community/docker-ce-desktop-mac)

### Setup the environment

Install bundler if you don't have it already installed

`sudo gem install bundler`

### Install dependencies

- Execute `bundle install`

### Run the tests

- Execute `rspec`

### Provider Step 0 (Setup)

Get familiraised with the code

![System diagram](https://github.com/doktor500/pact-workshop-provider/blob/master/resources/system-diagram.png "System diagram")

There are two microservices in this system. A `consumer` and a `provider` (this repository).

The "provider" is a PaymentService that validates if a credit card number is valid in the context of that system.

The "consumer" only makes requests to PaymentService to verify payment methods.

Checkout the [Consumer](https://github.com/doktor500/pact-workshop-consumer/) microservice, if you haven't already done so, so the directory structure looks like:

    drwxr-xr-x - pact-workshop-consumer
    drwxr-xr-x - pact-workshop-provider

Follow the instructions in the **Consumer's** readme file

### Provider Step 1 (Verifing an existing contract)

When we previously ran (in the consumer) the `spec/payment_service_client_spec.rb` test, it passed, but it also generated a `spec/pacts/paymentserviceclient-paymentservice.json` pact file that we can use to validate our assumptions on the provider side.

Pact has a rake task to verify the provider against the generated pact file. It can get the pact file from any URL (like the last successful CI build), but we are just going to use the local one.

Add to the `Rakefile` file the following line `require 'pact/tasks'` so it looks like this:

```ruby
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'
require 'rspec/core/rake_task'
require 'pact/tasks'

RSpec::Core::RakeTask.new(:spec)

task :default => [:spec]
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

When the test is fixed, in the `pact-workshop-consumer` run `git clean -df && git checkout . && git checkout consumer-step2`, also in the `pact-workshop-provider` run `git clean -df && git checkout . && git checkout provider-step2` and follow the instructions in this readme file

### Provider Step 2 (Using provider state)

In the `pact-workshop-provider` directory run again `rake pact:verify` and see how the new contract test added by the consumer is failing.

In order to define the necessary state in the provider side that is need it to make a test like this to pass, PACT introduces the concept of "provider states".

Go to the `spec/pact_helper.rb` file and change it to look like this:

```ruby
require 'pact/provider/rspec'

Pact.service_provider "PaymentService" do
  honours_pact_with 'PaymentServiceClient' do
    pact_uri '../pact-workshop-consumer/spec/pacts/paymentserviceclient-paymentservice.json'
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

A new provider state has been defined for "PaymentServiceClient", take into account that different provider states can be defined for different consumers.

Run again `rake pact:verify` and see all the tests passing.

When the tests are green, in the `pact-workshop-consumer` run `git clean -df && git checkout . && git checkout consumer-step3`, also in the `pact-workshop-provider` run `git clean -df && git checkout . && git checkout provider-step3` and finally checkout the [Broker](https://github.com/doktor500/pact-workshop-broker/) repository and follow the instructions in the **Broker's** readme file

### Provider Step 3 (Working with a PACT broker)

#### Verifying contracts with the pact-broker

In the `pact-workshop-provider` directory update the `pact_helper.rb` file with the following content in order to verify pacts in the broker.

```ruby
require 'pact/provider/rspec'

Pact.service_provider "PaymentService" do
  app_version '0.0.1'
  publish_verification_results true

  honours_pacts_from_pact_broker do
    pact_broker_base_url 'http://localhost:8000'
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

Now run `rake pact:verify`. You should see all tests passing. Navigate to `localhost:8000`, you should see the contract been verified.

In the `pact-workshop-consumer` run `git clean -df && git checkout . && git checkout consumer-step4`, also in the `pact-workshop-provider` run `git clean -df && git checkout . && git checkout provider-step4` to see the branches with all of this changes