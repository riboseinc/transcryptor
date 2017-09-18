# frozen_string_literal: true

class Transcryptor::Encryption::Base
  include Transcryptor::AttrEncrypted::ColumnNames

  def initialize(attribute_name, old_opts, new_opts, transcryptor_opts)
    @attribute_name = attribute_name
    @old_opts = old_opts
    @new_opts = new_opts
    @transcryptor_opts = transcryptor_opts
  end

  private

  def attr_encrypted_poro_class(attr_encrypted_opts)
    column_names_with_extra_columns =
      column_names_with_extra_columns(@attribute_name, @old_opts, @transcryptor_opts)

    attribute_name = @attribute_name

    Class.new(Transcryptor::AttrEncrypted::Poro) do
      attr_accessor(*column_names_with_extra_columns)
      attr_encrypted(attribute_name, attr_encrypted_opts)
    end
  end
end
