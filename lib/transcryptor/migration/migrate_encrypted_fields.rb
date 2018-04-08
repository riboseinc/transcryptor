# frozen_string_literal: true

module Transcryptor
  class Migration
    # :migrate_encrypted_fields! is called after model initialization
    # and updates encrypted field to the latest version
    module MigrateEncryptedFields
      def migrate_encrypted_fields!
        for_outdated_fields do |current_v, latest_v|
          opts = encrypted_attributes[field]
          value = public_send("#{field}_#{current_v}")
          encrypted_value = encrypt(field, value)
          public_send("#{opts[:prefix]}#{field}=", encrypted_value)
          public_send("#{field}_version=", latest_v)
        end

        save(validate: false)
      end

      def for_outdated_fields
        migrated_fields = Transcryptor::Migration.migrations[self.class]
        migrated_fields.each do |field, versions|
          latest_v  = versions[:latest_version].to_i
          current_v = public_send("#{field}_version").to_i
          next if latest_v == current_v

          yield current_v, latest_v
        end
      end

      private %i[migrate_encrypted_fields! for_outdated_fields]
    end
  end
end
