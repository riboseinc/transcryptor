class Transcryptor::Migration
  class << self
    attr_accessor :migrations, :latest_versions

    def draw(&block)
      @latest_versions = {}

      self.instance_eval(&block)
      evaluate_latest_versions!
      patch_models!
    end

    private

    def define_encryption(model_class,
                          field:,
                          options:,
                          version:,
                          version_field: nil)
      @migrations ||= {}
      @migrations[model_class] ||= {}
      @migrations[model_class][field] ||= {}
      @migrations[model_class][field][version] = options
    end

    def evaluate_latest_versions!
      @migrations.each do |model_class, fields|
        fields.each do |field, versions|
          @migrations[model_class][field][:latest_version] =
            @migrations[model_class][field].keys.max
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
        fields.each do |field, versions|
          versions.each do |version, opts|
            next if version == :latest_version

            versioned_field = "#{field}_#{version}".to_sym
            model_class.instance_eval do
              attr_encrypted versioned_field, **opts
            end

            current_opts   = model_class.encrypted_attributes[field]
            versioned_opts = model_class.encrypted_attributes[versioned_field]

            curr_field_name = get_field_name(field, current_opts)
            vers_field_name = get_field_name(versioned_field, versioned_opts)
            model_class.class_eval do
              define_method(vers_field_name) do
                public_send(curr_field_name)
              end

              define_method("#{vers_field_name}_iv") do
                public_send("#{curr_field_name}_iv")
              end

              define_method("#{vers_field_name}_salt") do
                public_send("#{curr_field_name}_salt")
              end
            end
          end
        end

        model_class.instance_eval do
          after_find :migrate_encrypted_fields!
        end

        model_class.class_eval do
          def migrate_encrypted_fields!
            Transcryptor::Migration.migrations[self.class].each do |field, versions|
              latest_v  = versions[:latest_version].to_i
              current_v = public_send("#{field}_version").to_i
              next if latest_v == current_v

              opts = encrypted_attributes[field]
              value = public_send("#{field}_#{current_v}")
              encrypted_value = encrypt(field, value)
              public_send("#{opts[:prefix]}#{field}=", encrypted_value)
              public_send("#{field}_version=", latest_v)
            end

            save(validate: false)
          end
          private :migrate_encrypted_fields!
        end
      end
    end

    def get_field_name(field, opts)
      "#{opts[:prefix]}#{field}#{opts[:suffix]}"
    end
  end
end
