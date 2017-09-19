module Transcryptor::AttrEncrypted::ColumnNames
  private

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

  def column_names_with_extra_columns(attribute_name, old_opts, transcryptor_opts)
    (column_names(attribute_name, old_opts) + transcryptor_opts[:extra_columns]).uniq
  end

  def column_names_to_nullify(attribute_name, new_opts, old_opts)
    column_names(attribute_name, old_opts) - column_names(attribute_name, new_opts)
  end

  def column_names_to_update(attribute_name, new_opts, old_opts)
    (column_names(attribute_name, old_opts) + column_names(attribute_name, new_opts)).uniq
  end
end
