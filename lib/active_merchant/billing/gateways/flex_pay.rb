module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FlexPayGateway < Gateway
      self.live_url = self.test_url = 'https://api.flexpay.io/v1'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'https://support.flexpay.io/support/home'
      self.display_name = 'FlexPay'

      self.money_format = :cents

      STANDARD_ERROR_CODE_MAPPING = {
        # Soft decline
        '20000' => STANDARD_ERROR_CODE[:call_issuer],
        '20003' => STANDARD_ERROR_CODE[:card_declined],
        # Hard decline
        '30001' => STANDARD_ERROR_CODE[:pickup_card],
        '30002' => STANDARD_ERROR_CODE[:pickup_card], # may be lost or stolen
        '30012' => STANDARD_ERROR_CODE[:incorrect_number],
        '30015' => STANDARD_ERROR_CODE[:processing_error], # invalid amount, eg. refund
        '30026' => STANDARD_ERROR_CODE[:expired_card],
        '33049' => STANDARD_ERROR_CODE[:invalid_cvc],
        # Validation error
        '50055' => STANDARD_ERROR_CODE[:invalid_expiry_date], # month missing
        '50056' => STANDARD_ERROR_CODE[:invalid_expiry_date], # month invalid
        '50057' => STANDARD_ERROR_CODE[:invalid_expiry_date], # year missing
        '50058' => STANDARD_ERROR_CODE[:invalid_expiry_date], # year invalid
        '50131' => STANDARD_ERROR_CODE[:processing_error], # transaction not found, eg. void
      }

      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('gateways/charge', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('gateways/authorize', post)
      end

      def capture(money, authorization, options={})
        post = {}
        post[:amount] = amount(money)
        post[:merchantTransactionId] = generate_unique_id
        commit("transactions/#{authorization}/capture", post)
      end

      def refund(money, authorization, options={})
        post = {}
        post[:amount] = amount(money)
        post[:merchantTransactionId] = generate_unique_id
        commit("transactions/#{authorization}/refund", post)
      end

      def void(authorization, options={})
        post = {}
        post[:merchantTransactionId] = generate_unique_id
        commit("transactions/#{authorization}/void", post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(%r((Authorization: Basic )\w+), '\1[FILTERED]').
          gsub(%r(("creditCardNumber\\?":\\?")[^"]*)i, '\1[FILTERED]').
          gsub(%r(("cvv\\?":\\?")[^"]*)i, '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        if options[:email].present?
          post[:paymentMethod][:email] = options[:email]
        else
          post[:customerId] = options[:customer_id] || generate_unique_id
        end
        add_shipping_address(post, options[:shipping_address]) if options[:shipping_address]
      end

      def add_address(post, creditcard, options)
        address = options[:billing_address] || options[:address] || {}
        post[:paymentMethod][:address1] = address[:address1] if address[:address1].present?
        post[:paymentMethod][:address2] = address[:address2] if address[:address2].present?
        post[:paymentMethod][:postalCode] = address[:zip]
        post[:paymentMethod][:city] = address[:city]
        post[:paymentMethod][:state] = address[:state]
        post[:paymentMethod][:country] = address[:country] if address[:country]
      end

      def add_shipping_address(post, address)
        post[:shippingAddress] = {}
        post[:shippingAddress][:address1] = address[:address1] if address[:address1].present?
        post[:shippingAddress][:address2] = address[:address2] if address[:address2].present?
        post[:shippingAddress][:postalCode] = address[:zip]
        post[:shippingAddress][:city] = address[:city]
        post[:shippingAddress][:state] = address[:state]
        post[:shippingAddress][:country] = address[:country] if address[:country]
      end

      def add_invoice(post, money, options)
        post[:merchantTransactionId] = generate_unique_id
        post[:orderId] = options[:order_id] || post[:merchantTransactionId]
        post[:amount] = amount(money)
        post[:currencyCode] = (options[:currency] || currency(money))
        post[:retryCount] = options[:retry_count] || 0
        post[:referenceData] = options[:reference_data] if options[:reference_data]
      end

      def add_payment(post, payment)
        post[:retainOnSuccess] = 'true'
        post[:paymentMethod] = {
          creditCardNumber: payment.number,
          expiryMonth: '%02d' % payment.month,
          expiryYear: payment.year,
          cvv: payment.verification_value,
          fullName: payment.name
        }
      end

      def headers(api_key)
        {
          'Authorization' => "Basic #{api_key}",
          'Content-Type' => 'application/json',
          'User-Agent'    => "ActiveMerchant::FlexPay/#{ActiveMerchant::FlexPay::VERSION}"
        }
      end

      def parse(body)
        return {} if body.blank?
        JSON.parse(body).fetch('transaction')
      rescue JSON::ParserError
        message = 'Unparsable response received from FlexPay. Please contact FlexPay if you continue to receive this message.'
        message += " (The raw response returned by the API was #{body.inspect})"
        { 'message' => message }
      end

      def commit(uri, parameters)
        url = (test? ? test_url : live_url)
        headers = headers(@options[:api_key])
        response = parse(ssl_post(get_url(uri), post_data(parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['response']['avsCode']),
          cvv_result: CVVResult.new(response['response']['cvvCode']),
          test: test?,
          error_code: error_code_from(response)
        )
      rescue ResponseError => e
        case e.response.code
        when '401', '405'
          return Response.new(false, e.response.message, {}, :test => test?)
        end
        raise
      end

      def get_url(uri)
        url = (test? ? test_url : live_url)
        "#{url}/#{uri}"
      end

      def success_from(response)
        response['responseCode'] == '10000'
      end

      def message_from(response)
        response['message']
      end

      def authorization_from(response)
        response['transactionId']
      end

      def post_data(parameters = {})
        JSON.generate(transaction: parameters)
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response['responseCode']]
        end
      end
    end
  end
end
