require 'test_helper'

class FlexPayTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FlexPayGateway.new(api_key: 'api_key')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'GRYBF34QLKME5KURAFWPQO6JOU', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal '5X7SQV53KJCUDDDGAFWPQU3D2Y', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_success response

    assert_equal '5X7SQV53KJCUDDDGAFWPQU3D2Y', response.authorization
    assert response.test?
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'K3A777DBM5JU3OTFAFWPQ257A4', response.authorization
    assert response.test?
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void('K3A777DBM5JU3OTFAFWPQ257A4', @options)
    assert_success response
    assert response.test?
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void('XX7SQV53KJCUDDDGAFWPQU3D2Y')
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:processing_error], response.error_code
  end

  def test_successful_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(successful_verify_response)
    assert_success response
    assert_equal 'M5FLIBIL2CZERIQEAFWPROMRYE', response.authorization
    assert_equal 'Approved.', response.message
    assert response.test?
  end

  def test_failed_verify
    response = stub_comms do
      @gateway.verify(@credit_card, @options)
    end.respond_with(failed_verify_response)
    assert_failure response
    assert_equal 'KUYCNVZLMNCEXMLUAFWPRTUG7I', response.authorization
    assert_equal 'Error / Invalid parameters in the request.', response.message
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-PRE_SCRUBBED
      opening connection to api.flexpay.io:443...
      opened
      starting SSL for api.flexpay.io:443...
      SSL established
      <- "POST /v1/gateways/charge HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==\r\nUser-Agent: ActiveMerchant::FlexPay/0.1.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.flexpay.io\r\nContent-Length: 492\r\n\r\n"
      <- "{\"transaction\":{\"merchantTransactionId\":\"45592038f232181b03030ef39fccb19c\",\"orderId\":\"45592038f232181b03030ef39fccb19c\",\"amount\":\"100\",\"currencyCode\":\"USD\",\"retainOnSuccess\":\"true\",\"paymentMethod\":{\"creditCardNumber\":\"4920201996449560\",\"expiryMonth\":9,\"expiryYear\":2020,\"cvv\":\"879\",\"fullName\":\"Longbob Longsen\",\"address1\":\"456 My Street\",\"address2\":\"Apt 1\",\"postalCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\"},\"retryCount\":0,\"customerId\":\"ef58583d-444a-4a1f-810c-d711b00b1f68\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Expires: -1\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Server: Microsoft-IIS/10.0\r\n"
      -> "Set-Cookie: .AspNet.TwoFactorCookie=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT\r\n"
      -> "Set-Cookie: .AspNet.ExternalCookie=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT\r\n"
      -> "Set-Cookie: .AspNet.ApplicationCookie=HWrm7uLazid0X3mAIgvKG4AhDaGYA2CzNB1Ge5emO1OafYj-mhMCUh0ACtinf8SgHaXbgyIEfDT4qrsSECl5ZeINeKoatymFbZEwSVNcdLMlcsWLjhEUsX82i0CZO0bblZwPw3viDXArR-HiSn8nU18AaWMA4GwPWQHGX_XYp1fxt5YOxOoal98GurLUfV4jrtYh--9jNd777oYHk_k5TTreq6Pu8q4W4TVryHcqUqaSXM1QgMy_Q3TOs0WtwWtIvbgMSRJebBP_FwPH5a6v5iss4xDofia1QKAjpqxEJYRx3Yn1hb3IbeRIhoPWo_pAtNK-pYX9koxmTZAcQm7SC6AiNEQItjocSANlp1aI46NHlktx1ibhdER1-m8PS7iNIvkiVpMNoKKPcxk2UW1hpDMbgXPxtscDb9uAjnPPmjXNUXLOu6ADYBZ067ALD9IdC_oqIFFGQNtDSddzMZ29Uef2OnThdP269JhBCR-1dO21pIIKaowTcSw3LsGhHJ3kZ3GjcedyBL88-r6aGazCb0culd7EK0qARK9y8d4rxYZowso3XqKvNT4trzecjp307Eu-CwtoEedLP_-ErozcFYT2JZ0Gsp_x_HDhgHAj_et67z44mVxluei3ScfbbGNc9ca1fF3o9b4O44YWcP3S5oHF8u84a-mWYnI4bXIEyL8; path=/; secure; HttpOnly\r\n"
      -> "Set-Cookie: ARRAffinity=a76a50ba664d5f979a92b87fa96814a39a02ad08ea740b7ba12f9ace3807d7f7;Path=/;HttpOnly;Domain=iisprodolympus01.azurewebsites.net\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "Request-Context: appId=cid-v1:97c9352c-de5e-4c1a-9b66-de58f0507cd4\r\n"
      -> "Access-Control-Expose-Headers: Request-Context\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Tue, 03 Sep 2019 17:34:11 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 1080\r\n"
      -> "\r\n"
      reading 1080 bytes...
      read 1080 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-POST_SCRUBBED
      opening connection to api.flexpay.io:443...
      opened
      starting SSL for api.flexpay.io:443...
      SSL established
      <- "POST /v1/gateways/charge HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]==\r\nUser-Agent: ActiveMerchant::FlexPay/0.1.0\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nHost: api.flexpay.io\r\nContent-Length: 492\r\n\r\n"
      <- "{\"transaction\":{\"merchantTransactionId\":\"45592038f232181b03030ef39fccb19c\",\"orderId\":\"45592038f232181b03030ef39fccb19c\",\"amount\":\"100\",\"currencyCode\":\"USD\",\"retainOnSuccess\":\"true\",\"paymentMethod\":{\"creditCardNumber\":\"[FILTERED]\",\"expiryMonth\":9,\"expiryYear\":2020,\"cvv\":\"[FILTERED]\",\"fullName\":\"Longbob Longsen\",\"address1\":\"456 My Street\",\"address2\":\"Apt 1\",\"postalCode\":\"K1C2N6\",\"city\":\"Ottawa\",\"state\":\"ON\",\"country\":\"CA\"},\"retryCount\":0,\"customerId\":\"ef58583d-444a-4a1f-810c-d711b00b1f68\"}}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Cache-Control: no-cache\r\n"
      -> "Pragma: no-cache\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Content-Encoding: gzip\r\n"
      -> "Expires: -1\r\n"
      -> "Vary: Accept-Encoding\r\n"
      -> "Server: Microsoft-IIS/10.0\r\n"
      -> "Set-Cookie: .AspNet.TwoFactorCookie=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT\r\n"
      -> "Set-Cookie: .AspNet.ExternalCookie=; path=/; expires=Thu, 01-Jan-1970 00:00:00 GMT\r\n"
      -> "Set-Cookie: .AspNet.ApplicationCookie=HWrm7uLazid0X3mAIgvKG4AhDaGYA2CzNB1Ge5emO1OafYj-mhMCUh0ACtinf8SgHaXbgyIEfDT4qrsSECl5ZeINeKoatymFbZEwSVNcdLMlcsWLjhEUsX82i0CZO0bblZwPw3viDXArR-HiSn8nU18AaWMA4GwPWQHGX_XYp1fxt5YOxOoal98GurLUfV4jrtYh--9jNd777oYHk_k5TTreq6Pu8q4W4TVryHcqUqaSXM1QgMy_Q3TOs0WtwWtIvbgMSRJebBP_FwPH5a6v5iss4xDofia1QKAjpqxEJYRx3Yn1hb3IbeRIhoPWo_pAtNK-pYX9koxmTZAcQm7SC6AiNEQItjocSANlp1aI46NHlktx1ibhdER1-m8PS7iNIvkiVpMNoKKPcxk2UW1hpDMbgXPxtscDb9uAjnPPmjXNUXLOu6ADYBZ067ALD9IdC_oqIFFGQNtDSddzMZ29Uef2OnThdP269JhBCR-1dO21pIIKaowTcSw3LsGhHJ3kZ3GjcedyBL88-r6aGazCb0culd7EK0qARK9y8d4rxYZowso3XqKvNT4trzecjp307Eu-CwtoEedLP_-ErozcFYT2JZ0Gsp_x_HDhgHAj_et67z44mVxluei3ScfbbGNc9ca1fF3o9b4O44YWcP3S5oHF8u84a-mWYnI4bXIEyL8; path=/; secure; HttpOnly\r\n"
      -> "Set-Cookie: ARRAffinity=a76a50ba664d5f979a92b87fa96814a39a02ad08ea740b7ba12f9ace3807d7f7;Path=/;HttpOnly;Domain=iisprodolympus01.azurewebsites.net\r\n"
      -> "X-AspNet-Version: 4.0.30319\r\n"
      -> "Request-Context: appId=cid-v1:97c9352c-de5e-4c1a-9b66-de58f0507cd4\r\n"
      -> "Access-Control-Expose-Headers: Request-Context\r\n"
      -> "X-Powered-By: ASP.NET\r\n"
      -> "Date: Tue, 03 Sep 2019 17:34:11 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Content-Length: 1080\r\n"
      -> "\r\n"
      reading 1080 bytes...
      read 1080 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"Approved","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"P3SUZWZ3V3YUFKRZAFWPQO6JUQ","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"4ff2cf8c-6956-4544-93e4-137680ed9c54","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"P3SUZWZ3V3YUFKRZAFWPQO6JUQ","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T17:46:03.556Z","storageState":"Stored"},"transactionId":"GRYBF34QLKME5KURAFWPQO6JOU","transactionDate":"2019-09-03T17:46:03.556Z","transactionStatus":1,"message":"Approved.","responseCode":"10000","transactionType":"Charge","merchantTransactionId":"6425d7acc1f812c3ff37467044f0b148","customerId":"4ff2cf8c-6956-4544-93e4-137680ed9c54","currencyCode":"USD","amount":100,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"0e0889dc-37fd-4207-879a-016cf83bc9a4","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"6425d7acc1f812c3ff37467044f0b148","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T17:46:03.509Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAABAID5IpeWMNcIAAAAAAAAAAAAAAAAAAAAADRwEu+QWphOqpEBbPg7yXU=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def failed_purchase_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"(No Match) – The CVD value provided does not match the CVD value associated with the card.","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"XTPDREKG7OZUTFUJAFWPQRU5QM","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"512a7018-3e28-4981-9422-d27d16c773cf","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"XTPDREKG7OZUTFUJAFWPQRU5QM","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T17:57:53.155Z","storageState":"Cached"},"transactionId":"UXXEM5WHV34E7GPCAFWPQRU5OM","transactionDate":"2019-09-03T17:57:53.155Z","transactionStatus":2,"message":"Declined - do not honor.","responseCode":"20003","transactionType":"Charge","merchantTransactionId":"036c1aecea22f9739fa45a3297285683","customerId":"512a7018-3e28-4981-9422-d27d16c773cf","currencyCode":"USD","amount":2008,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"ff2cbc39-f937-46be-9733-016cf8469d83","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"036c1aecea22f9739fa45a3297285683","retryDate":"2019-09-04T00:00:00Z","retryCount":0,"dateFirstAttempt":"2019-09-03T17:57:53.139Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"CAABACcDHD6YMNcIu0/mCVNVqUysIgFs3wTFEqXuRnbHrvhPmeIBbPhGnXM=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def successful_authorize_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"Approved","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T18:11:50.374Z","storageState":"Stored"},"transactionId":"5X7SQV53KJCUDDDGAFWPQU3D2Y","transactionDate":"2019-09-03T18:11:50.389Z","transactionStatus":1,"message":"Approved.","responseCode":"10000","transactionType":"Authorize","merchantTransactionId":"8abc2caf345d90156f060280058c9fb8","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","currencyCode":"USD","amount":100,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"c0a927fa-0150-4fee-aeb6-016cf85363f5","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"8abc2caf345d90156f060280058c9fb8","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T18:11:50.358Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAABALFwITGaMNcIAAAAAAAAAAAAAAAAAAAAAO3/KFe7UkVBjGYBbPhTY9Y=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def failed_authorize_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"(No Match) – The CVD value provided does not match the CVD value associated with the card.","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"RBUOU4AU4GZUBBVBAFWPQXCWG4","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"c1411e8d-b259-439b-a95c-378b9a141890","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"RBUOU4AU4GZUBBVBAFWPQXCWG4","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T18:21:36.695Z","storageState":"Cached"},"transactionId":"HCLZJ424YG4UPBG3AFWPQXCWE4","transactionDate":"2019-09-03T18:21:36.82Z","transactionStatus":2,"message":"Declined - do not honor.","responseCode":"20003","transactionType":"Authorize","merchantTransactionId":"44908859217f195bd4658a3098056336","customerId":"c1411e8d-b259-439b-a95c-378b9a141890","currencyCode":"USD","amount":2008,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"9ff00a5a-83c0-42b6-a56f-016cf85c56b4","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"44908859217f195bd4658a3098056336","retryDate":"2019-09-04T00:00:00Z","retryCount":0,"dateFirstAttempt":"2019-09-03T18:21:36.679Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"CAABACnqmo6bMNcIu0/mCVNVqUysIgFs3wTFEjiXlPNcwblHhNsBbPhcVic=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def successful_capture_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"Approved","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T18:11:50.816Z","storageState":"Stored"},"transactionId":"LMBWT6T4WN3EBG2KAFWPQU3FAM","transactionDate":"2019-09-03T18:11:50.852Z","transactionStatus":1,"message":"Approved.","responseCode":"10000","transactionType":"Capture","merchantTransactionId":"3e6f275228b0a428856c1c78900a61e0","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","currencyCode":"USD","amount":100,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"01ce6086-ab59-44c1-9791-016cf85365c4","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"8abc2caf345d90156f060280058c9fb8","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T18:11:50.358Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAACALFwITGaMNcIAAAAAAAAAAAAAAAAAAAAAO3/KFe7UkVBjGYBbPhTY9Y=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def failed_capture_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"(No Match) – The CVD value provided does not match the CVD value associated with the card.","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T18:32:47.088Z","storageState":"Stored"},"transactionId":"6PG4J4H3I2EULHHPAFWPQZUQ4A","transactionDate":"2019-09-03T18:32:47.104Z","transactionStatus":2,"message":"Declined - do not honor.","responseCode":"20003","transactionType":"Capture","merchantTransactionId":"4369113fefd1d430754aae860dcc68dd","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","currencyCode":"USD","amount":2008,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"bb041fc3-fe39-4216-b4a3-016cf8669100","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"8abc2caf345d90156f060280058c9fb8","retryDate":"2019-09-04T00:00:00Z","retryCount":0,"dateFirstAttempt":"2019-09-03T18:32:47.072Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"CAABAKbPMB6dMNcIu0/mCVNVqUysIgFs3wTFEvPNxPD7RolFnO8BbPhmkOA=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def successful_refund_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"Approved","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"AFANLGFYF2DELHR4AFWPQ254QY","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"4995930f-8ff3-45a7-8995-5a3eb350ae08","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"AFANLGFYF2DELHR4AFWPQ254QY","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T18:38:26.677Z","storageState":"Stored"},"transactionId":"K3A777DBM5JU3OTFAFWPQ257A4","transactionDate":"2019-09-03T18:38:26.677Z","transactionStatus":1,"message":"Approved.","responseCode":"10000","transactionType":"Refund","merchantTransactionId":"7fc9547cade6f3fe6c6bea7fee46b6d0","customerId":"4995930f-8ff3-45a7-8995-5a3eb350ae08","currencyCode":"USD","amount":100,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"4ff74b8d-68de-455c-b7e4-016cf86bbf75","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"5be79c1a174899efea8a307ec5a9bdb6","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T18:38:25.88Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAACABmxIuidMNcIAAAAAAAAAAAAAAAAAAAAAMzodiR/aNRBn8IBbPhrvFg=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def failed_refund_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"The external gateway has reported that you have submitted an invalid amount with your request.","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"XUNKT6E4IQFEJH2PAFWPQU3D4Y","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T18:52:28.654Z","storageState":"Stored"},"transactionId":"X6FPWMU3WFHUZPEYAFWPQ6EYJ4","transactionDate":"2019-09-03T18:52:28.654Z","transactionStatus":2,"message":"The external gateway has reported that you have submitted an invalid amount with your request.","responseCode":"30015","transactionType":"Refund","merchantTransactionId":"dea1d9363e1bff21abc2225d8e715d58","customerId":"2d188f76-d04c-4248-8adb-0d4689594d95","currencyCode":"USD","amount":3016,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"1d2b3248-1e7b-4307-b9c3-016cf878986e","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"8abc2caf345d90156f060280058c9fb8","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T18:11:50.358Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAAEALFwITGaMNcIAAAAAAAAAAAAAAAAAAAAAO3/KFe7UkVBjGYBbPhTY9Y=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def successful_void_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"Approved","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"OBMKZQZNCP6UDJ7FAFWPRCAMMI","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"4ef83777-83e2-4e8e-a5be-8209d7baadb0","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"OBMKZQZNCP6UDJ7FAFWPRCAMMI","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T19:09:21.799Z","storageState":"Stored"},"transactionId":"AGZTKJDIIMDELJS5AFWPRCANLQ","transactionDate":"2019-09-03T19:09:22.065Z","transactionStatus":1,"message":"Approved.","responseCode":"10000","transactionType":"Void","merchantTransactionId":"31d42652c7d2266077ef4a9d8c953cbf","customerId":"4ef83777-83e2-4e8e-a5be-8209d7baadb0","currencyCode":"USD","amount":100,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"eba6be95-22c0-47e1-84c3-016cf8880f11","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"e48fef767ce255bce807af5c417f7f70","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T19:09:21.368Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAACAErQFzqiMNcIAAAAAAAAAAAAAAAAAAAAAOBYaYpf0ApAlxEBbPiIDFg=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def failed_void_response
    %(
{"transaction":{"response":{"avsCode":null,"avsMessage":null,"cvvCode":null,"cvvMessage":null,"errorCode":null,"errorDetail":null},"paymentMethod":{"paymentMethodId":"W5H2KBAAXSGEVOE7AFWPRGU27A","creditCardNumber":"","expiryMonth":"","expiryYear":"","cvv":"","firstName":null,"lastName":null,"fullName":null,"customerId":"884a6325c5f164f3cc6d5f97bd3e3231","address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null,"email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":null,"lastFourDigits":"","firstSixDigits":"","cardType":null,"dateCreated":"2019-09-03T19:29:37.528Z","storageState":"Cached"},"transactionId":"T3TOBOFDRDAETC2XAFWPRGU2FU","transactionDate":"2019-09-03T19:29:37.528Z","transactionStatus":2,"message":"Original transaction not found using the field TransactionReferenceId.","responseCode":"50131","transactionType":"Void","merchantTransactionId":"7a238e520e2c86fa0a8d12b0c0b14e72","customerId":"884a6325c5f164f3cc6d5f97bd3e3231","currencyCode":null,"amount":0,"gatewayToken":"AAAAAAAAAAAAAAAAAAAAAAAAAA","gatewayType":"flexpay_declined","gatewayTransactionId":null,"merchantAccountReferenceId":null,"assignedGatewayToken":"AAAAAAAAAAAAAAAAAAAAAAAAAA","orderId":"","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T19:29:37.325Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAABAA4Z3A6lMNcIAAAAAAAAAAAAAAAAAAAAAJ7m4LijiMBJi1cBbPiami0=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def successful_verify_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"Approved","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"VZ2F4N3TMXKEJAA6AFWPROMQYY","creditCardNumber":"492020******9560","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"4e48ebc6-4665-46f8-9bff-7164922d25fb","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"VZ2F4N3TMXKEJAA6AFWPROMQYY","lastFourDigits":"9560","firstSixDigits":"492020","cardType":"VISA","dateCreated":"2019-09-03T20:03:26.878Z","storageState":"Stored"},"transactionId":"M5FLIBIL2CZERIQEAFWPROMRYE","transactionDate":"2019-09-03T20:03:26.925Z","transactionStatus":1,"message":"Approved.","responseCode":"10000","transactionType":"Void","merchantTransactionId":"d9b2bc0e52f480dbed804f16eb80edde","customerId":"4e48ebc6-4665-46f8-9bff-7164922d25fb","currencyCode":"USD","amount":100,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"f1377158-96f6-4a44-94d8-016cf8b9924d","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"00a877f9119d39f61a4272d143cd8795","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T20:03:26.505Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAACAF5RWMipMNcIAAAAAAAAAAAAAAAAAAAAAKc4SqHomNxHkBgBbPi5kKk=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end

  def failed_verify_response
    %(
{"transaction":{"response":{"avsCode":"S","avsMessage":"AVS not supported.","cvvCode":"M","cvvMessage":"(No Match) – The CVD value provided does not match the CVD value associated with the card.","errorCode":null,"errorDetail":""},"paymentMethod":{"paymentMethodId":"UU5QURQO5D7ERFZIAFWPRTUHA4","creditCardNumber":"400030******2220","expiryMonth":"09","expiryYear":"2020","cvv":"***","firstName":null,"lastName":null,"fullName":"Longbob Longsen","customerId":"d391605e-eaea-4416-9643-2b18b2ee0435","address1":"456 My Street","address2":"Apt 1","postalCode":"K1C2N6","city":"Ottawa","state":"ON","country":"CA","email":null,"phoneNumber":null,"paymentMethodType":"CreditCard","fingerprint":"UU5QURQO5D7ERFZIAFWPRTUHA4","lastFourDigits":"2220","firstSixDigits":"400030","cardType":"VISA","dateCreated":"2019-09-03T20:26:20.295Z","storageState":"Cached"},"transactionId":"KUYCNVZLMNCEXMLUAFWPRTUG7I","transactionDate":"2019-09-03T20:26:20.359Z","transactionStatus":2,"message":"Error / Invalid parameters in the request.","responseCode":"30016","transactionType":"Authorize","merchantTransactionId":"65517f03af824d82d3f3e461039d1458","customerId":"d391605e-eaea-4416-9643-2b18b2ee0435","currencyCode":"USD","amount":100,"gatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","gatewayType":"nmi","gatewayTransactionId":"fd5a65c5-4762-4afb-9b81-016cf8ce8747","merchantAccountReferenceId":"Sandbox123","assignedGatewayToken":"XNH6MCKTKWUUZLBCAFWN6BGFCI","orderId":"65517f03af824d82d3f3e461039d1458","retryDate":null,"retryCount":0,"dateFirstAttempt":"2019-09-03T20:26:20.282Z","description":null,"customerIp":null,"shippingAddress":{"address1":null,"address2":null,"postalCode":null,"city":null,"state":null,"country":null},"referenceData":"AAABAL4WLvusMNcIAAAAAAAAAAAAAAAAAAAAAFUwJtcrY0RLsXQBbPjOhvo=","disableCustomerRecovery":false,"customVariable1":null,"customVariable2":null,"customVariable3":null,"customVariable4":null,"customVariable5":null}}
    )
  end
end
