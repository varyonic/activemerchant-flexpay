$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "active_merchant/flex_pay"

require 'test/unit'
require 'mocha/test_unit'

require 'yaml'
require 'json'
require_relative 'comm_stub'

ActiveMerchant::Billing::Base.mode = :test

if ENV['DEBUG_ACTIVE_MERCHANT'] == 'true'
  require 'logger'
  ActiveMerchant::Billing::Gateway.logger = Logger.new(STDOUT)
  ActiveMerchant::Billing::Gateway.wiredump_device = STDOUT
end

module ActiveMerchant
  module Assertions
    AssertionClass = defined?(Minitest) ? MiniTest::Assertion : Test::Unit::AssertionFailedError

    # An assertion of a successful response:
    #
    #   # Instead of
    #   assert response.success?
    #
    #   # DRY that up with
    #   assert_success response
    #
    # A message will automatically show the inspection of the response
    # object if things go afoul.
    def assert_success(response, message=nil)
      clean_backtrace do
        assert response.success?, build_message(nil, "#{message + "\n" if message}Response expected to succeed: <?>", response)
      end
    end

    # The negative of +assert_success+
    def assert_failure(response, message=nil)
      clean_backtrace do
        assert !response.success?, build_message(nil, "#{message + "\n" if message}Response expected to fail: <?>", response)
      end
    end

    def assert_scrubbed(unexpected_value, transcript)
      regexp = (Regexp === unexpected_value ? unexpected_value : Regexp.new(Regexp.quote(unexpected_value.to_s)))
      refute_match regexp, transcript, 'Expected the value to be scrubbed out of the transcript'
    end

    private

    def clean_backtrace(&block)
      yield
    rescue AssertionClass => e
      path = File.expand_path(__FILE__)
      raise AssertionClass, e.message, (e.backtrace.reject { |line| File.expand_path(line) =~ /#{path}/ })
    end
  end

  module Fixtures
    HOME_DIR = RUBY_PLATFORM =~ /mswin32/ ? ENV['HOMEPATH'] : ENV['HOME'] unless defined?(HOME_DIR)
    LOCAL_CREDENTIALS = File.join(HOME_DIR.to_s, '.active_merchant/fixtures.yml') unless defined?(LOCAL_CREDENTIALS)
    DEFAULT_CREDENTIALS = File.join(File.dirname(__FILE__), 'fixtures.yml') unless defined?(DEFAULT_CREDENTIALS)

    private

    def default_expiration_date
      @default_expiration_date ||= Date.new((Time.now.year + 1), 9, 30)
    end

    def credit_card(number = '4242424242424242', options = {})
      defaults = {
        :number => number,
        :month => default_expiration_date.month,
        :year => default_expiration_date.year,
        :first_name => 'Longbob',
        :last_name => 'Longsen',
        :verification_value => options[:verification_value] || '123',
        :brand => 'visa'
      }.update(options)

      Billing::CreditCard.new(defaults)
    end

    def address(options = {})
      {
        name:     'Jim Smith',
        address1: '456 My Street',
        address2: 'Apt 1',
        company:  'Widgets Inc',
        city:     'Ottawa',
        state:    'ON',
        zip:      'K1C2N6',
        country:  'CA',
        phone:    '(555)555-5555',
        fax:      '(555)555-6666'
      }.update(options)
    end

    def all_fixtures
      @@fixtures ||= load_fixtures
    end

    def fixtures(key)
      data = all_fixtures[key] || raise(StandardError, "No fixture data was found for '#{key}'")

      data.dup
    end

    def load_fixtures
      [DEFAULT_CREDENTIALS, LOCAL_CREDENTIALS].inject({}) do |credentials, file_name|
        if File.exist?(file_name)
          yaml_data = YAML.safe_load(File.read(file_name), [], [], true)
          credentials.merge!(symbolize_keys(yaml_data))
        end
        credentials
      end
    end

    def symbolize_keys(hash)
      return unless hash.is_a?(Hash)

      hash.symbolize_keys!
      hash.each { |k, v| symbolize_keys(v) }
    end
  end
end

Test::Unit::TestCase.class_eval do
  include ActiveMerchant::Billing
  include ActiveMerchant::Assertions
  include ActiveMerchant::Fixtures

  def capture_transcript(gateway)
    transcript = ''
    gateway.class.wiredump_device = transcript

    yield

    transcript
  end

  def dump_transcript_and_fail(gateway, amount, credit_card, params)
    transcript = capture_transcript(gateway) do
      gateway.purchase(amount, credit_card, params)
    end

    File.open('transcript.log', 'w') { |f| f.write(transcript) }
    assert false, 'A purchase transcript has been written to transcript.log for you to test scrubbing with.'
  end
end
