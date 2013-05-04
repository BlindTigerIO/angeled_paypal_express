#encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "angel_ed_paypal_express/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "angel_ed_paypal_express"
  s.version     = AngelEdPaypalExpress::VERSION
  s.authors     = ["Evan Dietz"]
  s.email       = ["evan.r.dietz@gmail.com"]
  s.homepage    = "http://github.com/evanosky/angel_ed_paypal_express"
  s.summary     = "PaypalExpress integration with AngelEd"
  s.description = "PaypalExpress integration with AngelEd crowdfunding platform"

  s.files      = `git ls-files`.split($\)
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  s.add_dependency "rails", "~> 3.2.6"
  s.add_dependency "activemerchant", "~> 1.17.0"

  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "database_cleaner"
end
