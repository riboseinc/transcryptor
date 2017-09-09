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

  def equal_expression(conn, column, value)
    "#{column} = #{conn.quote_value(value)}"
  end

  def equal_expressions(values)
    connection.send(:with_connection) do |conn|
      values.map do |column, value|
        equal_expression(conn, column, value)
      end
    end
  end

  def selection_equal_expressions(values)
    connection.send(:with_connection) do |conn|
      values.map do |column, value|
        case value
        when nil
          "#{column} IS NULL"
        else
          equal_expression(conn, column, value)
        end
      end
    end
  end

end
