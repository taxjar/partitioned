$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "partitioned/version"

Gem::Specification.new do |s|
  s.name           = 'partitioned'
  s.version        = Partitioned::VERSION
  s.license        = 'New BSD License'
  s.date           = '2014-03-26'
  s.summary        = "Postgres table partitioning support for ActiveRecord."
  s.description    = "A gem providing support for table partitioning in ActiveRecord. Support is available for postgres databases. Other features include child table management (creation and deletion)."
  s.authors        = ["Keith Gabryelski", "Aleksandr Dembskiy", "Edward Slavich"]
  s.email          = 'keith@fiksu.com'
  s.files          = `git ls-files`.split("\n")
  s.test_files     = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path   = 'lib'
  s.homepage       = 'http://github.com/fiksu/partitioned'

  s.add_development_dependency 'rails', '~> 4.1.0' # Ruby on Rails web framework
  s.add_development_dependency 'pg', '~> 0.18.2' # Ruby interface to the PostgreSQL
  s.add_development_dependency 'rspec-rails', '~> 3.3.2' # Behaviour driven development
  s.add_development_dependency 'bulk_data_methods', '~> 3.0.0' # Bulk insert for ActiveRecord
  s.add_development_dependency 'byebug', '~> 5.0.0' # Debugging
  #s.add_development_dependency "jquery-rails"

end
