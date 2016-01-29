# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'capistrano-versionify'
  spec.version       = '0.2.0'
  spec.authors       = ['mprzytulski']
  spec.email         = ['michal@przytulski.pl']
  spec.summary       = %q{Manage versions in jira}
  spec.description   = %q{Manage versions in jira}
  spec.homepage      = 'https://github.com/mprzytulski/capistrano-versionify'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = ['versionify']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'capistrano', '>= 3.2.0'
  spec.add_runtime_dependency 'slack-notify'
  spec.add_runtime_dependency 'jira-ruby'
  spec.add_runtime_dependency 'podio'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
