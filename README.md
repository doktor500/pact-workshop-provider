### Requirements

- Ruby 2.4.4 (It is already installed if you are using Mac OS X)
- [Docker](https://hub.docker.com/editions/community/docker-ce-desktop-mac)

### Setup the environment

Install bundler 1.17.2 if you don't have it already installed

`sudo gem install bundler -v 1.17.2`

Verify that you have the right version by running `bundler --version`

If you have a more up to date versions of bundler, unistall them with `gem uninstall bundler` until the most up to date and default version of bundler is 1.17.2

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

When the test is fixed, in the `pact-workshop-consumer` directory run `git clean -df && git checkout . && git checkout consumer-step2`, also in the `pact-workshop-provider` directory run `git clean -df && git checkout . && git checkout provider-step2` and follow the instructions in the **Consumer's** readme file

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

When the tests are green, in the `pact-workshop-consumer` directory run `git clean -df && git checkout . && git checkout consumer-step3`, also in the `pact-workshop-provider` directory run `git clean -df && git checkout . && git checkout provider-step3` and finally checkout the [Broker](https://github.com/doktor500/pact-workshop-broker/) repository and follow the instructions in the **Broker's** readme file

### Provider Step 3 (Working with a PACT broker)

#### Verifying contracts with the pact-broker

In the `pact-workshop-provider` directory add `gem "pact_broker-client"` this gem to the `Gemfile`, the file should look like:

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

Pact.service_provider "PaymentService" do
  app_version `git rev-parse HEAD`.strip
  app_version_tags [`git rev-parse --abbrev-ref HEAD`.strip]
  publish_verification_results PUBLISH_VERIFICATION_RESULTS

  honours_pacts_from_pact_broker do
    pact_broker_base_url PACT_BROKER_BASE_URL, {token: PACT_BROKER_TOKEN}
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

In the `pact-workshop-consumer` directory run `git clean -df && git checkout . && git checkout consumer-step4`, also in the `pact-workshop-provider` directory run `git clean -df && git checkout . && git checkout provider-step4` and follow the instructions in the **Consumers's** readme file

### Provider Step 4 (Setting up CD)

#### Create heroku provider app

First we need to create a new environment variable.

In your `~/.basrc`, `~/.zshrc`, `~/.fishrc` etc, add the following line.

```bash
export GITHUB_USER=${YOUR_GITHUB_USERNAME}
```

Replacing ${YOUR_GITHUB_USERNAME} with your github user name.

Restart your terminal or source the file in **all* your active tabs `source ~/.basrc`, `source ~/.zshrc`, `source ~/.fishrc` etc.

You should be able to execute

```bash
echo $GITHUB_USER
```

And see the correct value.

Create a heroku app by executing `heroku create pact-provider-$GITHUB_USER`. This is the heroku app name that will be used to create the provider app URL, so we need a unique identifier to avoid collisions.

The app URL will look like `https://pact-provider-$GITHUB_USER.herokuapp.com/`

#### Create heroku configuration file

In the `pact-workshop-provider` directory run `touch Procfile` to create the configuration file for heroku to be able to run the app

The content of the `Procfile` file should look like:

```bash
web: bundle exec rackup config.ru -p $PORT
```

#### Configure circleci environment variables

Now, let's setup the environment variables need it to deploy the provider application. Click on the "WORKFLOWS" icon in the left hand side menu bar, and click on the settings icon for the `pact-workshop-provider` project.

Click on the "Environment variables" link.

We need to add 5 environment variables:

  - HEROKU_API_KEY
  - HEROKU_APP_NAME
  - PACT_BROKER_BASE_URL
  - PACT_BROKER_TOKEN
  - PACT_PARTICIPANT

Click on the "Add variables" button and add them one by one.

Use the `HEROKU_API_KEY` that you created in previous steps, and set the `HEROKU_APP_NAME` to `pact-provider-$GITHUB_USER`.

If you followed the steps availabe in the [pact-workshop-broker](https://github.com/doktor500/pact-workshop-broker) repository, you can get the `PACT_BROKER_BASE_URL` and `PACT_BROKER_TOKEN` by running

```bash
echo $PACT_BROKER_BASE_URL
echo $PACT_BROKER_TOKEN
```

The `PACT_PARTICIPANT` environment variable value should be set to `PaymentService`

#### Create configuration files for circleci

Now, let's create a YAML file to configure circleci.

In the `pact-workshop-provider` directory run `mkdir .circleci` and `touch .circleci/config.yml` to create the circle-ci configuration file.

The content of the `config.yml` file should look like:

```yaml
version: 2

jobs:
  build:
    working_directory: /tmp/project/
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout

      - restore_cache:
          key: circlev2-{{ checksum "Gemfile.lock" }}

      - run:
          name: Install dependencies
          command: bundle check --path=vendor/bundle || bundle install --path=vendor/bundle --jobs=4 --retry=3

      - save_cache:
          key: circlev2-{{ checksum "Gemfile.lock" }}
          paths:
            - vendor/bundle

      - run:
          name: Set git tag
          command: |
            echo `git tag -l --points-at HEAD` >> current-tag

      - run:
          name: Move cloned repository files to workspace
          command: mkdir workspace && mv `ls -A | grep -v "workspace"` ./workspace

      - persist_to_workspace:
          root: /tmp/project/
          paths:
            - workspace

  test:
    working_directory: /tmp/project/workspace
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - attach_workspace:
          at: /tmp/project

      - restore_cache:
          key: circlev2-{{ checksum "Gemfile.lock" }}

      - run:
          name: Install dependencies
          command: bundle check --path=vendor/bundle || bundle install --path=vendor/bundle --jobs=4 --retry=3

      - save_cache:
          key: circlev2-{{ checksum "Gemfile.lock" }}
          paths:
            - vendor/bundle

      - run:
          name: Run tests
          command: |
            mkdir -p /tmp/project/workspace/test-results
            TEST_FILES="$(circleci tests glob "spec/**/*_spec.rb" | circleci tests split --split-by=timings)"

            bundle exec rspec \
              --format progress \
              --format RspecJunitFormatter \
              --out /tmp/project/workspace/test-results/rspec.xml \
              --format progress \
              $TEST_FILES

      - store_test_results:
          path: /tmp/project/workspace/test-results

      - store_artifacts:
          path: /tmp/project/workspace/test-results
          destination: test-results

      - run:
          name: Verify contracts
          command: |
            export GIT_TAG=`cat current-tag`
            [[ $GIT_TAG == "first-deployment" ]] || PUBLISH_VERIFICATION_RESULTS=true rake pact:verify || true

      - run:
          name: Check if deployment can happen
          command: |
            export GIT_TAG=`cat current-tag`
            [[ $GIT_TAG == "first-deployment" ]] || bundle exec pact-broker can-i-deploy \
                --pacticipant ${PACT_PARTICIPANT} \
                --broker-base-url ${PACT_BROKER_BASE_URL} \
                --version ${CIRCLE_SHA1} \
                --to production

  deploy:
    working_directory: /tmp/project/workspace
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - attach_workspace:
          at: /tmp/project

      - restore_cache:
          key: circlev2-{{ checksum "Gemfile.lock" }}

      - run:
          name: Install dependencies
          command: bundle check --path=vendor/bundle || bundle install --path=vendor/bundle --jobs=4 --retry=3

      - save_cache:
          key: circlev2-{{ checksum "Gemfile.lock" }}
          paths:
            - vendor/bundle

      - run:
          name: Check if deployment can happen
          command: |
            export GIT_TAG=`cat current-tag`
            [[ $GIT_TAG == "first-deployment" ]] || bundle exec pact-broker can-i-deploy \
                --pacticipant ${PACT_PARTICIPANT} \
                --broker-base-url ${PACT_BROKER_BASE_URL} \
                --version ${CIRCLE_SHA1} \
                --to production

      - run:
          name: Deploy to production
          command: |
            git push https://heroku:${HEROKU_API_KEY}@git.heroku.com/${HEROKU_APP_NAME}.git master

            bundle exec pact-broker create-version-tag \
              --pacticipant ${PACT_PARTICIPANT} \
              --broker-base-url ${PACT_BROKER_BASE_URL} \
              --version ${CIRCLE_SHA1} \
              --tag production

  verify:
    working_directory: /tmp/project/workspace
    docker:
      - image: circleci/ruby:2.6.3

    steps:
      - checkout
      - attach_workspace:
          at: /tmp/project

      - run:
          name: Install dependencies
          command: bundle check --path=vendor/bundle || bundle install --path=vendor/bundle --jobs=4 --retry=3

      - run:
          name: Publish verification results
          command: |
            export GIT_TAG=`cat current-tag`
            [[ $GIT_TAG == "first-deployment" ]] || PUBLISH_VERIFICATION_RESULTS=true rake pact:verify

workflows:
  version: 2
  pipeline:
    jobs:
      - build
      - test:
          requires:
            - build
      - deploy:
          requires:
            - test
          filters:
            branches:
              only: master
      - verify:
          requires:
            - deploy
          filters:
            branches:
              only: master
```

Take a look the circleci config file. You will see that there is a workflow composed by 4 different jobs.

The first job named `build` performs the following actions:

  - Checkouts the code.
  - Installs and caches the project dependencies.
  - Creates a file that contains the current git tag.
  - Saves the current workspace.

The second job name `test` depends on the `build` does the following relevant operations:

  - Runs the test and stores the test results.
  - Executes the `rake pact:verify` task without publishing the verification results to the broker. This task is skipped if it is the first provider deployment.
  - Checks if the branch can be deployed using the `can-i-deploy` command.

The third job named `deploy` depends on the `test` job and it is only executed in master branch, it performs the following actions:

  - Checks if the deployment to production can happen (using the production tag). This task is skipped if it is the first provider deployment.
  - If the deployment can happen, it deploys and updates the `production` tag in the broker.

Finally the fourth and last job named `verify` depends on the `deploy` job and it is only executed in master branch, it performs the following actions:

  - Checkouts the code.
  - Installs the project dependencies.
  - Executes the `rake pact:verify` task publishing the verification results to the broker. This task is skipped if it is the first provider deployment.

In the `pact-workshop-consumer` directory run `git clean -df && git checkout . && git checkout consumer-step4`, also in the `pact-workshop-provider` directory run `git clean -df && git checkout . && git checkout provider-step4` and follow the instructions in the **Provider's** readme file

### Provider Step 5 (Deploy)

At this stage we are ready to deploy our provider API to heroku via circleci.

This is the first deployment and we will need to bypass some verification steps on CD. Since this is the first time we are deploying the provider to production we know there aren't any consumers using this API, so there is no need to verify if the deployment can happen. This is the only step in where we won't raise a pull request.

Run the following commands and in the `pact-workshop-provider` directory:

```bash
git checkout master && git rebase provider-step5
git tag -a first-deployment -m first-deployment
git push origin --tags && git push origin master
```

Go to circleci and see how the different CD steps are executed. You should see 4 CD steps: `build`, `test`, `deploy`, and `verify`. Wait until all the steps have completed successfully.

Once all the steps have completed successfully, execute the following curl request in your terminal.

```bash
curl --header "Content-Type: application/json" https://pact-provider-$GITHUB_USER.herokuapp.com/validate-payment-method/1234123412341234
```

It might take a while for the first request but you should see a 200 HTTP status code and a response with the following JSON body

```json
{
  "status": "valid"
}
```

Congratulations, your provider API is deployed to production and ready to be used by any consumer interested in your API

Navigate to the directory in where you checked out `pact-workshop-consumer`, run `git clean -df && git checkout . && git checkout consumer-step5` if you haven't already done so and follow the instructions in the **Consumers's** readme file
