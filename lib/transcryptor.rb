# encoding: utf-8

module Transcryptor
end

require 'transcryptor/version'
require 'transcryptor/abstract_adapter'
require 'transcryptor/decoder'
require 'transcryptor/active_record' if defined?(::ActiveRecord)
require 'transcryptor/data_mapper' if defined?(::DataMapper)

require 'attr_encrypted'
require 'transcryptor/attr_encrypted'
require 'transcryptor/encryption'
require 'transcryptor/instance'
