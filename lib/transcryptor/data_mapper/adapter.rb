class Transcryptor::DataMapper::Adapter < Transcryptor::AbstractAdapter
  def select_rows(table_name, columns)
    query = select_query(table_name, columns)

    connection.select(query).map { |record| record.to_h.stringify_keys }
  end

  def update_row(table_name, old_values, new_values)
    query = update_query(table_name, old_values, new_values)

    connection.execute(query)
  end

  private

  def equal_expressions(values)
    connection.send(:with_connection) do |conn|
      values.map { |column, value| "#{column} = #{conn.quote_value(value)}" }
    end
  end
end
