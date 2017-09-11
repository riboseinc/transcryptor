class Transcryptor::Instance
  attr_reader :adapter

  def initialize(adapter)
    @adapter = adapter
  end

  #
  # Re-Encrypts attribute and stores newly encrypted values in database.
  #
  # * <tt>table_name</tt> - Database table name where +attr_encrypted+ attribute is stored.
  # * <tt>attribute_name</tt> - Name of +attr_encrypted+ attribute,
  # * +old_opts+ - Configuration of +attr_encrypted+ before re-encryption.
  # * +new_opts+ - Target configuration of +attr_encrypted+ for given attribute.
  #
  # +old_opts+ and +new_opts+ support the following options:
  # * <tt>:prefix</tt> - Prefix for columns which are storing attribute's encrypted data (default: +'encrypted_'+).
  # * <tt>:suffix</tt> - Suffix for columns which are storing attribute's encrypted data (default: +''+).
  # * <tt>:if</tt> - Encrypt/decrypt on certain condition (default: <tt>true</tt>).
  # * <tt>:unless</tt> - Encrypt/decrypt on certain condition (default: <tt>false</tt>).
  # * <tt>:encode</tt> - Encode attribute string (default: <tt>true</tt>).
  # * <tt>:encode_iv</tt> - Encode attribute iv string (default: <tt>true</tt>).
  # * <tt>:encode_salt</tt> - Encode attribute salt string (default: <tt>true</tt>).
  # * <tt>:default_encoding</tt> - String encoding algorithm (default: +'m'+ (base64)). See Array#pack for more encoding options.
  # * +:marshal+ - Use +:marshaller+ to encrypt non-string value (default: <tt>false</tt>),
  # * +:marshaler+ - Class which will be used to serialize object before encryption (default: +Marshal+).
  # * +:dump_method+ - +:marshaler+ method to dump data (default: <tt>'dump'</tt>).
  # * +:load_method+ - +:marshaler+ method to load data (default: <tt>'load'</tt>).
  # * +:encryptor+ - Name of class which is responsible for encryption/decryption of attribute (default: +Encryptor+).
  # * +:encrypt_method+ - Method which will be called to encrypt data (default: +'encrypt'+).
  # * +:decrypt_method+ - Method which will be called to decrypt data (default: +'decrypt'+).
  # * +:mode+ - +attr_encrypted+ encryption mode (default: +:per_attribute_iv+). Available modes: +:per_attribute_iv+, +:per_attribute_iv_and_salt+, and +:single_iv_and_salt+.
  # * <tt>:algorithm</tt> - Encryption algorithm (default: +'aes-256-gcm'+).
  #
  # +transcryptor_opts+ supports the following options:
  # * <tt>:extra_columns</tt> - append extra columns on selection (default: [])
  # * +:before_decrypt+ - pre-hook before decryption and updating the row (default: -> (_old_row, _decryptor_class) {})
  # * +:after_encrypt+ - post-hook after encryption and updating row (default: -> (_decrypted_value, _new_row, _encryptor_class) {})

  def re_encrypt(table_name, attribute_name, old_opts, new_opts, transcryptor_opts = {})
    old_opts.reverse_merge!(attr_encrypted_default_options)
    new_opts.reverse_merge!(attr_encrypted_default_options)
    transcryptor_opts.reverse_merge!(transcryptor_default_options)

    all_columns = (column_names(attribute_name, old_opts) + transcryptor_opts[:extra_columns]).uniq

    rows = adapter.select_rows(table_name, all_columns)

    decryptor_class = attr_encrypted_poro_class(attribute_name, old_opts, all_columns)
    encryptor_class = attr_encrypted_poro_class(attribute_name, new_opts, all_columns)

    rows.each do |old_row|
      transcryptor_opts[:before_decrypt].call(old_row, decryptor_class)

      decrypted_value = decrypt_value(old_row, attribute_name, decryptor_class)
      new_row = encrypt_value(decrypted_value, old_row, attribute_name, encryptor_class, transcryptor_opts[:extra_columns])

      adapter.update_row(table_name, old_row, new_row)

      transcryptor_opts[:after_encrypt].call(decrypted_value, new_row, encryptor_class)
    end
  end

  private

  def attr_encrypted_poro_class(attribute_name, attr_encrypted_opts, attributes)
    Class.new(Transcryptor::Poro) do
      attr_accessor(*attributes)
      attr_encrypted(attribute_name, attr_encrypted_opts)
    end
  end

  def decrypt_value(row, attribute_name, decryptor_class)
    decryptor_class.new(row).send(attribute_name)
  end

  def encrypt_value(value, row, attribute_name, encryptor_class, extra_columns)
    encryptor_class_instance = encryptor_class.new(row)
    encryptor_class_instance.send("#{attribute_name}=", value)
    opts = encryptor_class.encrypted_attributes[attribute_name]

    all_columns =
      (column_names(attribute_name, opts) + extra_columns).uniq.map(&:to_s)

    encryptor_class_instance.instance_values.slice(*all_columns)
  end

  def encrypted_column(attribute_name, opts)
    "#{opts[:prefix]}#{attribute_name}#{opts[:suffix]}"
  end

  def encrypted_column_iv(attribute_name, opts)
    "#{opts[:prefix]}#{attribute_name}#{opts[:suffix]}_iv"
  end

  def encrypted_column_salt(attribute_name, opts)
    "#{opts[:prefix]}#{attribute_name}#{opts[:suffix]}_salt"
  end

  def column_names(attribute_name, opts)
    column_names = [encrypted_column(attribute_name, opts)]

    case opts[:mode].to_sym
    when :per_attribute_iv
      column_names << encrypted_column_iv(attribute_name, opts)
    when :per_attribute_iv_and_salt
      column_names << encrypted_column_iv(attribute_name, opts)
      column_names << encrypted_column_salt(attribute_name, opts)
    else
    end

    column_names
  end

  def attr_encrypted_default_options
    {
      prefix:            'encrypted_',
      suffix:            '',
      if:                true,
      unless:            false,
      encode:            true, # changed from false to true as we are working with DB only
      encode_iv:         true,
      encode_salt:       true,
      default_encoding:  'm',
      marshal:           false,
      marshaler:         Marshal,
      dump_method:       'dump',
      load_method:       'load',
      encryptor:         Encryptor,
      encrypt_method:    'encrypt',
      decrypt_method:    'decrypt',
      mode:              :per_attribute_iv,
      algorithm:         'aes-256-gcm',
    }.freeze
  end

  def transcryptor_default_options
    {
      extra_columns: [],
      before_decrypt: -> (_old_row, _decryptor_class) {},
      after_encrypt: -> (_decrypted_value, _new_row, _encryptor_class) {},
    }
  end
end
