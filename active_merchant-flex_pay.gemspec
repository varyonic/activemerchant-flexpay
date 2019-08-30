
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "active_merchant/flex_pay/version"

Gem::Specification.new do |spec|
  spec.name          = "active_merchant-flex_pay"
  spec.version       = ActiveMerchant::FlexPay::VERSION
  spec.authors       = ["Piers Chambers"]
  spec.email         = ["piers@varyonic.com"]

  spec.summary       = %q{Active Merchant extension to support FlexPay.io}
  spec.homepage      = "https://github.com/varyonic/active_merchant-flex_pay"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'activemerchant'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency('test-unit', '~> 3')
  spec.add_development_dependency('mocha', '~> 1')
end
