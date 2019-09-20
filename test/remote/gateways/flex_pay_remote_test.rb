require 'test_helper'

class RemoteFlexPayTest < Test::Unit::TestCase
  def setup
    @gateway = FlexPayGateway.new(fixtures(:flex_pay))

    @amount = 100
    @credit_card = credit_card('4920201996449560', verification_value: '879')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Approved.', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      order_id: '1',
      ip: "127.0.0.1",
      email: "joe@example.com",
      customer_id: 12345,
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'Approved.', response.message
    assert_equal response.params['paymentMethod']['email'], 'joe@example.com'
    assert_equal response.params['paymentMethod']['customerId'], '12345'
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount = 2008, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined - do not honor.', response.message
  end

  def test_failed_purchase_with_retry
    response = @gateway.purchase(@amount = 2008, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined - do not honor.', response.message

    @options[:retry_count] = 1
    @options[:reference_data] = response.params['referenceData']
    response = @gateway.purchase(@amount = 2008, @credit_card, @options)
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'Approved.', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount = 2008, @credit_card, @options)
    assert_failure response
    assert_equal 'Declined - do not honor.', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount = 2008, '5X7SQV53KJCUDDDGAFWPQU3D2Y')
    assert_failure response
    assert_equal 'Declined - do not honor.', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'Approved.', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount = 3016, '5X7SQV53KJCUDDDGAFWPQU3D2Y')
    assert_failure response
    assert_equal 'The external gateway has reported that you have submitted an invalid amount with your request.', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Approved.', void.message
  end

  def test_failed_void
    response = @gateway.void('XX7SQV53KJCUDDDGAFWPQU3D2Y')
    assert_failure response
    assert_equal 'Original transaction not found using the field TransactionReferenceId.', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match %r{Approved.}, response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{Error / Invalid parameters in the request.}, response.message
  end

  def test_invalid_login
    gateway = FlexPayGateway.new(api_key: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{Unauthorized}, response.message
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end

end
