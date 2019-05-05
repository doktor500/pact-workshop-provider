### Provider Step 5 (Deploy)

At this stage, we are ready to deploy our provider API to heroku via circleci.

This is the first deployment and we will need to bypass some verification steps on CD. Since this is the first time we are deploying the provider to production we know there aren't any consumers using this API, so there is no need to verify if the deployment can happen. This is the only step in where we won't raise a pull request.

Run the following commands and in the `pact-workshop-provider` directory:

```bash
git checkout master && git checkout master && git merge -X theirs --allow-unrelated-histories provider-step5
git tag -a first-deployment -m first-deployment
git push origin --tags && git push --force origin master
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

Congratulations, your provider API is deployed to production and ready to be used by any consumer interested in your API.

Navigate to the directory in where you checked out `pact-workshop-consumer`, run `git clean -df && git checkout . && git checkout consumer-step5` if you haven't already done so and follow the instructions in the **Consumers's** readme file
