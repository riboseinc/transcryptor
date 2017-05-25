# encoding: utf-8
require "transcryptor/version"
require "active_support"
require "active_record"

# To use Transcryptor, here is a sample migration that showcases this:
#
# class ReencryptUsersAndDocumentsWithNewKeys < ActiveRecord::Migration
#
#   def transcryptor
#     Transcryptor.init(self)
#   end
#
#   # +keyifier+ mirrors the functionality provided by the :key Proc in
#   # attr_encrypted.
#   # NOTE: Has to return the entire Hash.
#   #
#   def old_keyifier
#     -> opts {
#       opts[:key] = ENV['old_master_encryption_key'] + opts[:key]
#       opts
#     }
#   end
#
#   def new_keyifier
#     -> opts {
#       opts[:key] = ENV['new_master_encryption_key'] + opts[:key]
#       opts
#     }
#   end
#
#   def table_column_spec
#     {
#       users:  {
#         id_column: :id,
#         columns: {
#           email: {
#             prefix: 'encrypted_',
#             key: :ekey,
#           },
#           birthday: {
#             prefix: 'encrypted_',
#             key: :ekey,
#           },
#         }
#       },
#       documents:  {
#         id_column: :id,
#         columns: {
#           passphrase: {
#             prefix: 'encrypted_',
#             key: :ekey,
#           },
#         }
#       },
#     }
#   end
#
#   def up
#     transcryptor.updown_migrate(
#       table_column_spec,
#       {
#         algorithm:      'aes-256-cbc',
#         decode64_value: true,
#       }, {
#         algorithm:      'aes-256-gcm',
#         encode64_iv:    true,
#         encode64_value: true,
#         iv: true,
#       },
#       old_keyifier,
#       new_keyifier,
#     )
#   end
#
#   def down
#     transcryptor.updown_migrate(
#       table_column_spec,
#       {
#         algorithm:      'aes-256-gcm',
#         decode64_iv:    true,
#         decode64_value: true,
#       }, {
#         algorithm:      'aes-256-cbc',
#         iv:             false,
#         salt:           false,
#         encode64_value: true,
#         insecure_mode:  true,
#       },
#       new_keyifier,
#       old_keyifier,
#     )
#   end
#
module Transcryptor

  # Initialize Transcryptor instance with the migration instance.
  # This step allows typical migration methods like #execute to be invoked
  # from this gem.
  def self.init(migration_instance = Kernel.caller)
    Instance.new(migration_instance)
  end

  class Instance

    attr_accessor :migration_instance

    def initialize(migration_instance)
      self.migration_instance = migration_instance
    end

    def execute *args
      puts "\e[38;5;141m"
      puts puts args
      puts "\e[0m"
      migration_instance.execute *args
    end

    # Meant to be used by both #up and #down.
    #
    # table_column_spec:
    # {
    #   table1:  {
    #     id_column: :id,
    #     columns: {
    #       column1: {
    #         prefix: 'encoded_',
    #         key: :encryption_key_1,
    #       },
    #       column2: {
    #         prefix: 'xXx_en_ing_',
    #         key: :encryption_key_2,
    #         suffix: '_crypted_xXx',
    #       },
    #     }
    #   },
    #   table2:  {
    #     id_column: :id,
    #     columns: {
    #       column3: {
    #         prefix: 'encoded_',
    #         key: :encryption_key_3,
    #       },
    #       column4: {
    #         prefix: 'xXx_en_ing_',
    #         key: :encryption_key_4,
    #         suffix: '_crypted_xXx',
    #       },
    #     }
    #   },
    # }
    def updown_migrate(table_column_spec, old_spec, new_spec, decrypt_opts_fn, encrypt_opts_fn)

      # puts "table column spec is:"
      # pp table_column_spec

      table_column_spec.each do |table_name, table_spec|
        id_name      = table_spec[:id_column]
        column_specs = table_spec[:columns]

        relevant_column_names =
          [ id_name ] + column_specs.map do |column_name, column_spec|
            column_prefix    = column_spec[:prefix]
            column_key_field = column_spec[:key]
            column_suffix    = column_spec[:suffix]
            full_column_name = :"#{column_prefix}#{column_name}#{column_suffix}"

            [ full_column_name, column_key_field ] + %i[iv salt].reduce([]) do |acc, suffix|
              extra_column_name = :"#{full_column_name}_#{suffix}"
              acc << extra_column_name if column_exists?(table_name, extra_column_name)
              acc
            end
          end.flatten.compact.uniq

        # puts "relevant column names are:"
        # pp relevant_column_names

        execute(
          "SELECT #{relevant_column_names.join(', ')} FROM `#{table_name}`"
        ).each do |_db_values|
          id, _dontcare = _db_values

          # A map: { :db_field_name => "value" }
          db_values =
            Hash[relevant_column_names.map(&:to_sym).zip(_db_values)]

          # Build up reencryption params to pass to reencrypt().
          encrypted_attrs = column_specs.keys.map do |attr_name|

            column_spec      = column_specs[attr_name]
            column_prefix    = column_spec[:prefix]
            column_key_field = column_spec[:key]
            column_suffix    = column_spec[:suffix]
            full_column_name = :"#{column_prefix}#{attr_name}#{column_suffix}"

            encrypted_value = db_values[:"#{full_column_name}"]
            key             = db_values[:"#{column_key_field}"]
            # +key+ could be nil, but it's OK, since it may be provided via 
            # other means, e.g. encrypt_opts_fn and decrypt_opts_fn.

            unless encrypted_value.nil? || encrypted_value == ""
              res = {
                attr_name: attr_name,
                key:       key,
                value:     encrypted_value,
              }

              # Merge in iv and/or salt as appropriate.
              %i[iv salt].reduce(res) do |acc, suffix|
                extra_column_name = :"#{full_column_name}_#{suffix}"
                if relevant_column_names.include?(extra_column_name)
                  acc[suffix] = db_values[extra_column_name]
                end
                acc
              end
            end
          end.compact

          next if encrypted_attrs.empty?

          re_encrypt(
            table_name,
            id,
            encrypted_attrs.map do |attr|
              {
                # These would be in +attr+ as approprate.
                # salt:      old_salt,
                # iv:        old_iv,
                # key:       old_key,
                # attr_name: attr_name,
                # value:     encrypted_value,
                old: attr.merge(old_spec),
                new: { key: attr[:key], }.merge(new_spec),
              }
            end,
            decrypt_opts_fn,
            encrypt_opts_fn,
          )
        end

      end
    end

    # +table_name+ is the SQL table name for the record at id = +record_id+.
    # +attrs_specs+ is an Array like so: [ {
    #   old: {
    #     key:       String,
    #     value:     String,
    #     attr_name: String,
    #     algorithm:      String,
    #     iv:        String | Nil,
    #     salt:      String | Nil,
    #   },
    #   new:         {
    #     algorithm:      String,
    #     iv:        String | Bool,
    #     salt:      String | Bool,
    #   },
    # } ]
    #
    # Assumptions: Encrypted attribute SQL column names are all prefixed with 
    # "encrypted_",  and also suffixed with "_iv" & "_salt" for the corresponding 
    # iv and salt.
    #
    def re_encrypt(table_name, record_id, attrs_specs, decrypt_opts_fn, encrypt_opts_fn, column_prefix = 'encrypted_')
      # puts "attrs_specs:"
      # pp attrs_specs

      set_statement = attrs_specs.map do |attr_spec|

        old_spec = attr_spec[:old]
        new_spec = attr_spec[:new]

        plain_stuff    = dec(old_spec) do |opts|
          decrypt_opts_fn.call(opts)
        end

        result_stuff   = enc(new_spec.merge(value: plain_stuff[:value])) do |opts|
          encrypt_opts_fn.call(opts)
        end

        new_ciphertext = result_stuff[:value]
        attr_name      = old_spec[:attr_name]

        extra_columns = %i[iv salt].reduce({}) do |acc, suffix|
          extra_column_name = "#{column_prefix}#{attr_name}_#{suffix}"
          acc[suffix] = extra_column_name if column_exists?(table_name, extra_column_name)
          raise Exception.new(
            "Error: Column #{extra_column_name} doesn't exist " \
            "but is needed for #{suffix}.  Aborting."
          ) if result_stuff[suffix] && !acc[suffix]
          acc
        end

        (
          [
            "`#{column_prefix}#{attr_name}` = #{ActiveRecord::Base.sanitize(new_ciphertext)}"
          ] +
          extra_columns.reduce([]) do |acc, (suffix, extra_column_name)|
            acc << "`#{extra_column_name}` = #{
              ActiveRecord::Base.sanitize(result_stuff[suffix])
            }"
            acc
          end.flatten
        ).map{|s| s.force_encoding('utf-8')}

      end.join(', ')

      update_statement = <<-EOF
        UPDATE `#{table_name}`
        SET #{set_statement}
        WHERE id = #{ActiveRecord::Base.sanitize(record_id)}
      EOF

      puts puts "\e[38;5;42m"
      puts update_statement
      puts "\e[0m"
      execute(update_statement)
    end

    # XXX: MySQL2 specific! TODO: adapt to different backends
    # Return +true+ iff column +_column_name+ exists in table +_table_name+.
    # Cached for performance.
    def column_exists?(_table_name, _column_name)
      table_name  = _table_name.to_sym
      column_name = _column_name.to_sym
      @column_exists ||= {}
      @column_exists[table_name] ||= {}
      exists = @column_exists[table_name][column_name]
      !exists.nil? ? exists : @column_exists[table_name][column_name] =
        begin
          raw_result = execute <<-EOF
            SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
            WHERE
              column_name  = #{ActiveRecord::Base.sanitize column_name} AND
              table_name   = #{ActiveRecord::Base.sanitize table_name} AND
              TABLE_SCHEMA = DATABASE()
          EOF

          result = raw_result.to_a.flatten[0] == 1
          result
        end
    end

    class NoKeyException < StandardError ; end

    # +iv+ can be +true+.  If so, we generate IV for you.
    # If +iv+ is truthy, we use +iv+ directly.
    # Likewise for +salt+.
    # Default algorithm is 'aes-256-gcm' as per default of attr_encrypted v3.
    # You may opt to use 'aes-256-cbc', like in attr_encrypted v1.
    #
    # When given a block, the encryptor params can be modified before passing 
    # over to Encryptor for the encryption process.
    #
    # +decode64_iv+
    #   - if +true+, base64-decodes the given +iv+ before passing to Encryptor.
    # +decode64_salt+
    #   - if +true+, base64-decodes the given +salt+ before passing to 
    #   Encryptor.
    # +decode64_value+
    #   - if +true+, base64-decodes the given +value+ before passing to 
    #   Encryptor.
    #
    # +encode64_iv+
    #   - if +true+, base64-encodes the +iv+ output by Encryptor.
    # +encode64_salt+
    #   - if +true+, base64-encodes the +salt+ output by Encryptor.
    # +encode64_value+
    #   - if +true+, base64-encodes the +value+ output by Encryptor.
    #
    def enc opts
      value = opts[:value]
      ek    = opts[:key]
      algo  = opts[:algorithm] || 'aes-256-gcm'

      iv = opts[:iv]
      iv = OpenSSL::Cipher::Cipher.new(algo).random_iv if iv === true

      salt = opts[:salt]
      salt = SecureRandom.random_bytes if salt === true

      cryptor_opts = {
        value:         value,
        key:           ek,
        algorithm:     algo,
        value_present: false, # so as to force regenerating of random_iv @ encryptor
        insecure_mode: false || opts[:insecure_mode],
      }

      has_iv   = !iv.nil?   &&   iv != ''
      has_salt = !salt.nil? && salt != ''

      # pp "in enc: opts = #{opts.pretty_inspect}"

      iv    = Base64.decode64(iv)    if has_iv   && opts.delete(:decode64_iv)
      salt  = Base64.decode64(salt)  if has_salt && opts.delete(:decode64_salt)
      value = Base64.decode64(value) if opts.delete(:decode64_value)

      cryptor_opts = cryptor_opts.merge(iv: iv)     if has_iv
      cryptor_opts = cryptor_opts.merge(salt: salt) if has_salt
      cryptor_opts = cryptor_opts.merge(value: value)

      if block_given?
        cryptor_opts = yield cryptor_opts
        ek             = cryptor_opts[:key]
      end

      raise NoKeyException.new("encryption :key is nil") if ek.nil?

      result_stuff = {
        value: Encryptor.encrypt(cryptor_opts),
        key:   ek,
      }

      iv    = Base64.encode64(iv)    if has_iv   && opts.delete(:encode64_iv)
      salt  = Base64.encode64(salt)  if has_salt && opts.delete(:encode64_salt)
      value = Base64.encode64(result_stuff[:value]) if opts.delete(:encode64_value)

      result_stuff[:value] = value

      # puts "has iv? #{has_iv}     = #{iv.pretty_inspect}"
      # puts "has salt? #{has_salt} = #{salt.pretty_inspect}"

      result_stuff = result_stuff.merge(iv: iv)     if has_iv
      result_stuff = result_stuff.merge(salt: salt) if has_salt
      result_stuff
    end

    #
    # When given a block, the encryptor params can be modified before passing 
    # over to Encryptor for the encryption process.
    #
    # +insecure_mode+ is automatically set to +true+ if no +iv+ is provided.
    # It can also be specified by user but will not be able to override the 
    # +true+ if no +iv+ is given.  This should match what is expected to work 
    # in Encryptor.
    #
    # +decode64_iv+
    #   - if +true+, base64-decodes the given +iv+ before passing to Encryptor.
    # +decode64_salt+
    #   - if +true+, base64-decodes the given +salt+ before passing to 
    #   Encryptor.
    # +decode64_value+
    #   - if +true+, base64-decodes the given +value+ before passing to 
    #   Encryptor.
    #
    # +encode64_iv+
    #   - if +true+, base64-encodes the given +iv+ before passing to Encryptor.
    # +encode64_salt+
    #   - if +true+, base64-encodes the given +salt+ before passing to 
    #   Encryptor.
    # +encode64_value+
    #   - if +true+, base64-encodes the given +value+ before passing to 
    #   Encryptor.
    #
    # NOTE: The operations decode64-* and encode64-* decribed above may cancel 
    # each other out.
    #
    # This is a design uncertainty and may change in a later version.
    #
    def dec opts
      value = opts[:value]
      key   = opts[:key]
      algo  = opts[:algorithm] || 'aes-256-gcm'
      iv    = opts[:iv]
      salt  = opts[:salt]

      has_iv   = iv   &&   iv != ''
      has_salt = salt && salt != ''

      iv    = Base64.decode64(iv)    if has_iv   && opts.delete(:decode64_iv)
      salt  = Base64.decode64(salt)  if has_salt && opts.delete(:decode64_salt)
      value = Base64.decode64(value) if opts.delete(:decode64_value)

      iv    = Base64.encode64(iv)    if has_iv   && opts.delete(:encode64_iv)
      salt  = Base64.encode64(salt)  if has_salt && opts.delete(:encode64_salt)
      value = Base64.encode64(value) if opts.delete(:encode64_value)

      cryptor_opts = {
        value:         value,
        key:           key,
        iv:            iv,
        salt:          salt,
        algorithm:     algo,

        # e.g. key length may be too short
        insecure_mode: ! has_iv || opts[:insecure_mode],
      }

      # puts "key was: #{key}"

      if block_given?
        # puts "wow yay block given."
        cryptor_opts = yield cryptor_opts
        # puts "new cryptor_opts is:"
        # pp cryptor_opts
      end

      key = cryptor_opts[:key]

      key = Base64.encode64(key) if opts.delete(:encode64_key)
      key = Base64.decode64(key) if opts.delete(:decode64_key)

      cryptor_opts[:key] = key

      # puts "transcryptor#dec,opts=#{cryptor_opts.pretty_inspect}"

      raise NoKeyException.new("encryption :key is nil") if key.nil?

      {
        value: Encryptor.decrypt(cryptor_opts)
      }
    end

  end
end
