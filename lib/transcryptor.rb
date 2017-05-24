require "transcryptor/version"
require "active_record/base"

module Transcryptor

  def self.init(migration_instance = Kernel.caller)
    Instance.new(migration_instance)
  end

  class Instance

    attr_accessor :migration_instance

    def initialize(migration_instance)
      self.migration_instance = migration_instance
    end

    # def keyifier
    #   -> opts {
    #     opts[:key] = INDIGO_CONFIG[:master_encryption_key] + opts[:key]
    #     opts
    #   }
    # end
    #
    # def table_column_spec
    #   {
    #     users:  %i[answer question],
    #     spaces: %i[description],
    #   }
    # end
    #
    # def up
    #   Transcryptor.updown_migrate(
    #     table_column_spec,
    #     {
    #       algorithm: 'aes-256-cbc',
    #     }, {
    #       algorithm: 'aes-256-gcm',
    #       iv: true,
    #     },
    #     keyifier,
    #     keyifier,
    #     'encrypted_',
    #   )
    # end
    #
    # def down
    #   Transcryptor.updown_migrate(
    #     table_column_spec,
    #     {
    #       algorithm: 'aes-256-gcm',
    #     }, {
    #       algorithm: 'aes-256-cbc',
    #       insecure_mode: true,
    #     },
    #     keyifier,
    #     keyifier,
    #     'encrypted_',
    #   )
    # end


    def execute *args
      puts "\e[38;5;141m"
      puts puts args
      puts "\e[0m"
      migration_instance.execute *args
    end

    def updown_migrate(table_column_spec, old_spec, new_spec, decrypt_opts_fn, encrypt_opts_fn)

      # table_column_spec
      {
        table1:  {
          id_column: :id,
          columns: {
            column1: {
              prefix: 'encoded_',
              key: :encryption_key_1,
            },
            column2: {
              prefix: 'xXx_en_ing_',
              key: :encryption_key_2,
              suffix: '_crypted_xXx',
            },
          }
        },
      }

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

          # reencrypt(table_name, id, ekey, old_algo, new_algo, reencrypt_params)
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
        )

      end.join(', ')

      update_statement = <<-EOF
        UPDATE `#{table_name}`
        SET #{set_statement}
        WHERE id = #{ActiveRecord::Base.sanitize(record_id)}
      EOF

      # execute(update_statement)
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

      iv    = Base64.encode64(iv)    if has_iv   && opts.delete(:encode64_iv)
      salt  = Base64.encode64(salt)  if has_salt && opts.delete(:encode64_salt)
      value = Base64.encode64(value) if opts.delete(:encode64_value)

      iv    = Base64.decode64(iv)    if has_iv   && opts.delete(:decode64_iv)
      salt  = Base64.decode64(salt)  if has_salt && opts.delete(:decode64_salt)
      value = Base64.decode64(value) if opts.delete(:decode64_value)

      cryptor_opts = cryptor_opts.merge(iv: iv) if has_iv
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

      result_stuff = result_stuff.merge(iv: iv) if has_iv
      result_stuff = result_stuff.merge(salt: salt) if has_salt
      result_stuff
    end

    #
    # When given a block, the encryptor params can be modified before passing 
    # over to Encryptor for the encryption process.
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

      # ek = (INDIGO_CONFIG[:master_encryption_key] + u.ekey)
      cryptor_opts = {
        value:         value,
        key:           key,
        iv:            iv,
        salt:          salt,
        algorithm:     algo,
        # e.g. key length may be too short
        insecure_mode: ! has_iv || opts[:insecure_mode],
      }

      puts "key was: #{key}"

      if block_given?
        puts "wow yay block given."
        cryptor_opts = yield cryptor_opts
        puts "new cryptor_opts is:"
        pp cryptor_opts
      end

      key = cryptor_opts[:key]
      puts "after 383 key=#{key.pretty_inspect}"

      key = Base64.encode64(key) if opts.delete(:encode64_key)
      key = Base64.decode64(key) if opts.delete(:decode64_key)

      puts "after mmm, key=#{key.pretty_inspect}"

      cryptor_opts[:key] = key

      puts "transcryptor#dec,opts=#{cryptor_opts.pretty_inspect}"

      raise NoKeyException.new("encryption :key is nil") if key.nil?

      {
        value: Encryptor.decrypt(cryptor_opts)
      }
    end

    # like #enc but base64-encodes :value, :iv and :salt.
    def enc64 opts, &blk
      result_stuff = enc(opts, &blk)
      iv           = result_stuff[:iv]
      salt         = result_stuff[:salt]
      value        = result_stuff[:value]

      has_iv   = iv   &&   iv != ''
      has_salt = salt && salt != ''

      result_stuff[:iv]    = Base64.encode64(iv)   if has_iv
      result_stuff[:salt]  = Base64.encode64(salt) if has_salt
      result_stuff[:value] = Base64.encode64(value)
      result_stuff
    end

    # like #dec but assumes :value, :iv and :salt are base64-encoded.
    def dec64 opts, &blk
      new_opts = {}.merge(opts)
      iv    = new_opts[:iv]
      salt  = new_opts[:salt]
      value = new_opts[:value]

      has_iv   = !iv.nil?   &&   iv != ''
      has_salt = !salt.nil? && salt != ''

      new_opts[:iv]    = Base64.decode64(iv)   if has_iv
      new_opts[:salt]  = Base64.decode64(salt) if has_salt
      new_opts[:value] = Base64.decode64(value)
      dec(new_opts, &blk)
    end

  end
end
