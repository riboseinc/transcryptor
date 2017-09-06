class Transcryptor::AbstractAdapter
  attr_reader :connection

  def initialize(connection)
    @connection = connection
  end

  def select_rows(_table_name, _columns)
    raise NotImplementedError, "#{self.class}#select_rows not implemented"
  end

  def update_row(_table_name, _old_values, _new_values)
    raise NotImplementedError, "#{self.class}#update_row not implemented"
  end

  private

  def select_query(table_name, columns)
    <<-SQL
      SELECT #{columns.join(', ')}
      FROM #{table_name}
    SQL
  end

  def update_query(table_name, old_values, new_values)
    old_values.keys.each { |column_name| new_values[column_name] ||= nil }

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
