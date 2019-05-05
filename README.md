### Provider Step 4 (Setting up CD)

#### Create heroku provider app

First, we need to create a new environment variable.

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

Now, let's set up the environment variables need it to deploy the provider application. Click on the "WORKFLOWS" icon in the left-hand side menu bar, and click on the settings icon for the `pact-workshop-provider` project.

Click on the "Environment variables" link.

We need to add 5 environment variables:

  - HEROKU_API_KEY
  - HEROKU_APP_NAME
  - PACT_BROKER_BASE_URL
  - PACT_BROKER_TOKEN
  - PACT_PARTICIPANT

Click on the "Add variables" button and add them one by one.

Use the `HEROKU_API_KEY` that you created in previous steps, and set the `HEROKU_APP_NAME` to `pact-provider-$GITHUB_USER`.

If you followed the steps available in the [pact-workshop-broker](https://github.com/doktor500/pact-workshop-broker) repository, you can get the `PACT_BROKER_BASE_URL` and `PACT_BROKER_TOKEN` by running

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
            [[ $GIT_TAG == "first-deployment" ]] || PUBLISH_VERIFICATION_RESULTS=true CONSUMER_VERSION_TAG=production \
              rake pact:verify

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

Take a look at the circleci config file. You will see that there is a workflow composed of 4 different jobs.

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

Finally, the fourth and last job named `verify` depends on the `deploy` job and it is only executed in master branch, it performs the following actions:

  - Checkouts the code.
  - Installs the project dependencies.
  - Executes the `rake pact:verify` task publishing the verification results to the broker. This task is skipped if it is the first provider deployment.

In the the `pact-workshop-provider` directory run `git clean -df && git checkout . && git checkout provider-step5` and follow the instructions in the **Provider's** readme file
