$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "enterprise_mti/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "enterprise_mti"
  s.platform    = Gem::Platform::RUBY
  s.version     = EnterpriseMti::VERSION
  s.authors     = ["Ersin Akinci"]
  s.email       = ["ersinakinci@gmail.com"]
  s.homepage    = "https://github.com/earksiinni/enterprise_mti"
  s.summary     = "Multiple table inheritance for Active Record with referential integrity"
  s.description = <<-DESC
    Enterprise MTI is gem that adds multiple table inheritance to Active
    Record models backed by database-level referential integrity.  The
    design and the project's name are inspired by Dan Chak's book,
    "Enterprise Rails," from which some code has been taken.
  DESC
  s.license     = 'MIT'

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", ">= 4.0.0"

  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
end
