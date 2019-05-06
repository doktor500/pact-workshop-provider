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
