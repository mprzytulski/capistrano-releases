# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "capistrano-releases"
  spec.version       = "0.1.0"
  spec.authors       = ["Michal Przytulski"]
  spec.email         = ["michal@przytulski.pl"]
  spec.description   = %q{Uses git commits to recognize tracker stories and generates ChangeLog.}
  spec.summary       = %q{Uses git commits to recognize tracker stories and generates ChangeLog.}
  spec.homepage      = "https://github.com/mprzytulski/capistrano-releases"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'

  spec.add_runtime_dependency     'pp'
  spec.add_runtime_dependency     'capistrano', '< 3.0'
  spec.add_runtime_dependency     'jira-ruby'
end