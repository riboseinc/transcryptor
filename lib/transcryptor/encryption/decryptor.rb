# frozen_string_literal: true

class Transcryptor::Encryption::Decryptor < Transcryptor::Encryption::Base
  def initialize(attribute_name, old_opts, new_opts, transcryptor_opts)
    super
    @decryptor_class = attr_encrypted_poro_class(@old_opts)
  end

  def decrypt(row)
    call_before_decrypt_hook(row)
    @decryptor_class.new(row).send(@attribute_name)
  end

  private

  def call_before_decrypt_hook(row)
    @transcryptor_opts[:before_decrypt].call(row, @decryptor_class)
  end
end
