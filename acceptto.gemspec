# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'acceptto/version'

Gem::Specification.new do |spec|
  spec.name          = 'acceptto'
  spec.version       = Acceptto::VERSION
  spec.authors       = ['Acceptto']
  spec.email         = ['info@acceptto.com']
  spec.summary       = %q{Acceptto client}
  spec.description   = %q{Acceptto client wrapper.}
  spec.homepage      = 'http://www.acceptto.com'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'bundler'
  spec.add_dependency 'rake'
  spec.add_dependency 'oauth2'
end
