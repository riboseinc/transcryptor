class Transcryptor::ActiveRecord::Adapter < Transcryptor::AbstractAdapter
  def select_rows(table_name, columns)
    query = <<-SQL
      SELECT #{columns.join(', ')}
      FROM #{table_name}
    SQL

    connection.exec_query(query).to_hash
  end

  def update_row(table_name, old_values, new_values)
    query = <<-SQL
      UPDATE #{table_name}
      SET #{equal_expressions(new_values).join(', ')}
      WHERE #{equal_expressions(old_values).join(' AND ')}
    SQL

    connection.exec_update(query)
  end

  private

  def equal_expressions(values)
    values.map { |column, value| "#{column} = #{connection.quote(value)}" }
  end
end
