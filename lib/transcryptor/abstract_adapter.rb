class Transcryptor::AbstractAdapter
  attr_reader :connection

  def initialize(connection)
    @connection = connection
  end

  private

  def select_query(table_name, columns)
    <<-SQL
      SELECT #{columns.join(', ')}
      FROM #{table_name}
    SQL
  end

  def update_query(table_name, old_values, new_values)
    <<-SQL
      UPDATE #{table_name}
      SET #{equal_expressions(new_values).join(', ')}
      WHERE #{equal_expressions(old_values).join(' AND ')}
    SQL
  end

  def equal_expressions(_values)
    raise NotImplementedError, "#{self.class}#equal_expressions not implemented"
  end
end
