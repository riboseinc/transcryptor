# frozen_string_literal: true

class Transcryptor::Poro
  extend AttrEncrypted

  def initialize(row = {})
    row.each do |column_name, column_value|
      instance_variable_set("@#{column_name}", column_value)
    end
  end
end
