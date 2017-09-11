module Transcryptor::ActiveRecord::ZeroDowntime
  def self.included(base)
    base.extend ClassMethods

    base.class_eval do
      after_initialize :transcryptor_migrate

      @transcryptor_migrate_attributes = []
      class << self
        attr_reader :transcryptor_migrate_attributes
      end
    end
  end

  def transcryptor_migrate
    self.class.transcryptor_migrate_attributes.each do |attribute|
      send("#{attribute[:new]}=", send(attribute[:old]))
    end
  end

  module ClassMethods
    def transcryptor_migrate(old_attribute, new_attribute)
      @transcryptor_migrate_attributes << {old: old_attribute, new: new_attribute}

      options = attr_encrypted_options.merge(encrypted_attributes[old_attribute])
      encrypted_attribute_name = "#{options[:prefix]}#{old_attribute}#{options[:suffix]}"

      define_method("#{old_attribute}=") do |value|
        send("#{encrypted_attribute_name}=", encrypt(old_attribute, value))
        instance_variable_set("@#{old_attribute}", value)
        send("#{new_attribute}=", value)
      end
    end
  end
end
