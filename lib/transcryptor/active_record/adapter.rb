class Transcryptor::ActiveRecord::Adapter < Transcryptor::AbstractAdapter
  def select_rows(table_name, columns, selection_criteria = nil)
    query = select_query(table_name, columns, selection_criteria)

    connection.exec_query(query).to_hash
  end

  def update_row(table_name, old_values, new_values)
    query = update_query(table_name, old_values, new_values)

    connection.exec_update(query, "SQL", [])
  end

  private

  def equal_expression(column, value)
    "#{column} = #{connection.quote(value)}"
  end
end
