# frozen_string_literal: true

module Transcryptor
  # Plugin module for VersionedFields gem
  module Decoder
    def decode_with_previous_settings(migration_data, **options)
      # We only need to decode field value once
      # Encoding will be performed by :attr_encypted itself
      return public_send(migration_data.field) if @transcryptor_decode_migrated

      field     = migration_data.field
      current_v = migration_data.version

      generate_versioned_fields!(field, current_v, options)

      opts = encrypted_attributes[field]
      public_send("#{field}_#{current_v}")
      value = public_send("#{field}_#{current_v}")
      encrypted_value = encrypt(field, value)
      public_send("#{opts[:prefix]}#{field}=", encrypted_value)

      (@transcryptor_decode_migrated = true) && value
    end

    private

    def generate_versioned_fields!(field, version, opts)
      versioned_field = "#{field}_#{version}".to_sym
      model_class.instance_eval do
        attr_encrypted versioned_field, **opts
      end

      curr_field_name = get_field_name(field)
      vers_field_name = get_field_name(versioned_field)

      redefine_versioned_fields!(vers_field_name, curr_field_name)
    end

    def redefine_versioned_fields!(vers_field_name,
                                   curr_field_name)
      model_class.class_eval do
        define_method(vers_field_name) { public_send(curr_field_name) }

        define_method("#{vers_field_name}_iv") do
          public_send("#{curr_field_name}_iv")
        end

        define_method("#{vers_field_name}_salt") do
          public_send("#{curr_field_name}_salt")
        end
      end
    end

    def get_field_name(field)
      opts = model_class.encrypted_attributes[field]
      "#{opts[:prefix]}#{field}#{opts[:suffix]}"
    end

    def model_class
      self.class
    end
  end
end
