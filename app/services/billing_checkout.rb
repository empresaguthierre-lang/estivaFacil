class BillingCheckout
  def self.call(company:, success_url:, cancel_url:)
    Stripe::Checkout::Session.create(
      mode: "subscription",
      customer: company.stripe_customer_id,
      line_items: [ { price: ENV.fetch("STRIPE_PRICE_ID"), quantity: 1 } ],
      success_url: success_url,
      cancel_url: cancel_url,
      metadata: { company_id: company.id }
    )
  end
end
