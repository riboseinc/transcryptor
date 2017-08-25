# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'transcryptor/version'

Gem::Specification.new do |spec|
  spec.name          = "transcryptor"
  spec.version       = Transcryptor::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = %q{Assists your everyday re-encryption needs, in Rails.}
  spec.homepage      = "https://github.com/riboseinc/transcryptor"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "attr_encrypted", "~> 3.0"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.10.0"

  spec.add_development_dependency "sqlite3", "~> 1.3"
  spec.add_development_dependency "activerecord", "~> 4.0"

  spec.add_development_dependency "dm-sqlite-adapter", "~> 1.0"
  spec.add_development_dependency "data_mapper", "~> 1.0"

  spec.add_development_dependency "simplecov", "~> 0.15.0"
  spec.add_development_dependency "codeclimate-test-reporter", '~> 1.0'
end
