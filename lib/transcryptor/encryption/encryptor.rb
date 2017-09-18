# frozen_string_literal: true

class Transcryptor::Encryption::Encryptor < Transcryptor::Encryption::Base
  def initialize(attribute_name, old_opts, new_opts, transcryptor_opts)
    super
    @encryptor_class = attr_encrypted_poro_class(@new_opts)
  end

  def encrypt(decrypted_value, old_row)
    encryptor_instance = @encryptor_class.new(old_row)
    encryptor_instance.public_send("#{@attribute_name}=", decrypted_value)

    nullify_row(encryptor_instance)

    call_after_encrypt_hook(decrypted_value, encryptor_instance.row)

    extract_row(encryptor_instance)
  end

  private

  def nullify_row(encryptor_instance)
    column_names_to_nullify = column_names_to_nullify(@attribute_name, @new_opts, @old_opts)

    column_names_to_nullify.each do |column_name|
      encryptor_instance.public_send("#{column_name}=", nil)
    end
  end

  def extract_row(encryptor_instance)
    column_names_to_update = column_names_to_update(@attribute_name, @new_opts, @old_opts)

    column_names_to_update.each_with_object({}) do |column_name, row|
      row[column_name] = encryptor_instance.public_send(column_name)
    end
  end

  def call_after_encrypt_hook(decrypted_value, row)
    @transcryptor_opts[:after_encrypt].call(decrypted_value, row, @encryptor_class)
  end
end
