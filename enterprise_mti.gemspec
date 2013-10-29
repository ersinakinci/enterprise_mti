$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "enterprise_mti/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "enterprise_mti"
  s.version     = EnterpriseMti::VERSION
  s.authors     = ["Ersin Akinci"]
  s.email       = ["ersinakinci@gmail.com"]
  s.homepage    = "TODO"
  s.summary     = "Multiple table inheritance for ActiveRecord models with referential integrity"
  s.description = <<-DESC
    Enterprise MTI is a 
  DESC
  s.license     = 'MIT'

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.0.0"

  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
end
