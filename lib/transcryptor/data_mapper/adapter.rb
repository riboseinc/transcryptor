class Transcryptor::DataMapper::Adapter < Transcryptor::AbstractAdapter
  def select_rows(table_name, columns, selection_criteria = nil)
    query = select_query(table_name, columns, selection_criteria)

    connection.select(query).map { |record| record.to_h.stringify_keys }
  end

  def update_row(table_name, old_values, new_values)
    query = update_query(table_name, old_values, new_values)

    connection.execute(query)
  end

  private

  def equal_expression(column, value)
    connection.send(:with_connection) do |conn|
      "#{column} = #{conn.quote_value(value)}"
    end
  end
end
