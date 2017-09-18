class Transcryptor::Instance
  include Transcryptor::AttrEncrypted::ColumnNames

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
    prepare_opts(old_opts, new_opts, transcryptor_opts)

    decryptor, encryptor =
      initialize_encryption_classes(attribute_name, old_opts, new_opts, transcryptor_opts)

    column_names_with_extra_columns =
      column_names_with_extra_columns(attribute_name, old_opts, transcryptor_opts)

    @adapter.select_rows(table_name, column_names_with_extra_columns).each do |old_row|
      decrypted_value = decryptor.decrypt(old_row)
      new_row = encryptor.encrypt(decrypted_value, old_row)

      @adapter.update_row(table_name, old_row, new_row)
    end
  end

  private

  def prepare_opts(old_opts, new_opts, transcryptor_opts)
    old_opts.reverse_merge!(attr_encrypted_default_options)
    new_opts.reverse_merge!(attr_encrypted_default_options)
    transcryptor_opts.reverse_merge!(transcryptor_default_options)
  end

  def initialize_encryption_classes(attribute_name, old_opts, new_opts, transcryptor_opts)
    [
      Transcryptor::Encryption::Decryptor.new(attribute_name, old_opts, new_opts, transcryptor_opts),
      Transcryptor::Encryption::Encryptor.new(attribute_name, old_opts, new_opts, transcryptor_opts)
    ]
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
