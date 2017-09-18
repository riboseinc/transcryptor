# frozen_string_literal: true

class Transcryptor::AttrEncrypted::Poro
  extend AttrEncrypted

  def initialize(row = {})
    row.each do |column_name, column_value|
      instance_variable_set("@#{column_name}", column_value)
    end
  end

  def row
    Hash[instance_variables.map { |name| [name[1..-1], instance_variable_get(name)] }]
  end
end
