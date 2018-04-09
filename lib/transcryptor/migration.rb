# frozen_string_literal: true

require 'transcryptor/migration/migrate_encrypted_fields'
require 'transcryptor/migration/specify_latest_version'

module Transcryptor
  # Allows ZeroDowntime migration using version columns.
  # Usage example:
  # Transcryptor.draw do
  #   define_encryption User,
  #     field: :ssn,
  #     options: {
  #       key:       '67c3800d1572d9d964a6ff3bd821ed02',
  #       algorithm: 'aes-256-gcm'
  #     },
  #     version: 20180401000000
  #
  #   define_encryption User,
  #     field: :ssn,
  #     options: {
  #       key:       '0726c4d149fa59523bc47d592151584b',
  #       algorithm: 'id-aes192-GCM'
  #     },
  #     version: 20180401000001
  # end
  class Migration
    class << self
      attr_accessor :migrations, :latest_versions

      def draw(&block)
        @latest_versions = {}

        instance_eval(&block)
        evaluate_latest_versions!
        patch_models!
      end

      private

      def define_encryption(model_class,
                            field:,
                            options:,
                            version:)
        @migrations ||= {}
        @migrations[model_class] ||= {}
        @migrations[model_class][field] ||= {}
        @migrations[model_class][field][version] = options
      end

      def evaluate_latest_versions!
        @migrations.each do |model_class, fields|
          fields.each do |field, versions|
            @migrations[model_class][field][:latest_version] ||=
              versions.keys.max
          end
        end
      end

      # Generates methods for every field's version:
      # user.ssn
      # user.ssn_20180401000000
      # user.ssn_20180401000001
      # user.ssn_20180401000002
      def patch_models!
        migrations.each do |model_class, fields|
          generate_versioned_fields_if_needed!(model_class, fields)

          model_class.instance_eval do
            after_find :migrate_encrypted_fields!
            after_initialize :specify_latest_version!, if: :new_record?
          end

          model_class.class_eval do
            include Transcryptor::Migration::MigrateEncryptedFields
            include Transcryptor::Migration::SpecifyLatestVersion
          end
        end
      end

      def generate_versioned_fields_if_needed!(model_class, fields)
        fields.each do |field, versions|
          versions.each do |version, opts|
            next if version == :latest_version

            generate_versioned_fields!(model_class, field, version, opts)
          end
        end
      end

      def generate_versioned_fields!(model_class, field, version, opts)
        versioned_field = "#{field}_#{version}".to_sym
        model_class.instance_eval do
          attr_encrypted versioned_field, **opts
        end

        curr_field_name = get_field_name(field, model_class)
        vers_field_name = get_field_name(versioned_field, model_class)

        redefine_versioned_fields!(
          model_class, vers_field_name, curr_field_name
        )
      end

      def redefine_versioned_fields!(model_class,
                                     vers_field_name,
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

      def get_field_name(field, model_class)
        opts = model_class.encrypted_attributes[field]
        "#{opts[:prefix]}#{field}#{opts[:suffix]}"
      end
    end
  end
end
