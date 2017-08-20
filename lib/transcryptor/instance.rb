class Transcryptor::Instance
  attr_reader :adapter

  def initialize(adapter)
    @adapter = adapter
  end

  def re_encrypt(table_name, attribute_name, old_opts, new_opts)
    old_opts.reverse_merge!(transcryptor_default_options)
    new_opts.reverse_merge!(transcryptor_default_options)

    rows = adapter.select_rows(table_name, column_names(attribute_name, old_opts))

    decryptor_class = attr_encrypted_poro_class(attribute_name, old_opts)
    encryptor_class = attr_encrypted_poro_class(attribute_name, new_opts)

    rows.each do |old_row|
      decrypted_value = decrypt_value(old_row, attribute_name, decryptor_class, old_opts)
      new_row = encrypt_value(decrypted_value, attribute_name, encryptor_class, new_opts)
      adapter.update_row(table_name, old_row, new_row)
    end
  end

  private

  def attr_encrypted_poro_class(attribute_name, opts)
    Class.new(Transcryptor::Poro) do
      attr_encrypted(attribute_name, opts)
    end
  end

  def decrypt_value(row, attribute_name, decryptor_class, _opts)
    decryptor_class.new(row).send(attribute_name)
  end

  def encrypt_value(value, attribute_name, encryptor_class, opts)
    encryptor_class_instance = encryptor_class.new
    encryptor_class_instance.send("#{attribute_name}=", value)

    encryptor_class_instance.instance_values.slice(*column_names(attribute_name, opts))
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

  def transcryptor_default_options
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
      algorithm:         'aes-256-gcm'
    }.freeze
  end
end
