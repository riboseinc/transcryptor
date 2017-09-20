class Transcryptor::AbstractAdapter
  attr_reader :connection

  def initialize(connection)
    @connection = connection
  end

  def select_rows(_table_name, _columns, _selection_criteria = nil)
    raise NotImplementedError, "#{self.class}#select_rows not implemented"
  end

  def update_row(_table_name, _old_values, _new_values)
    raise NotImplementedError, "#{self.class}#update_row not implemented"
  end

  private

  def select_query(table_name, columns, selection_criteria = nil)
    where_clause = case selection_criteria
                   when Proc then selection_criteria.call
                   else selection_criteria
                   end
    <<-SQL
      SELECT #{columns.join(', ')}
      FROM #{table_name}
      #{
        if selection_criteria.blank?
          ''
        else
          "WHERE #{where_clause}"
        end
      }
    SQL
  end

  def update_query(table_name, old_values, new_values)
    <<-SQL
      UPDATE #{table_name}
      SET #{equal_expressions(new_values).join(', ')}
      WHERE #{select_equal_expressions(old_values).join(' AND ')}
    SQL
  end

  def equal_expressions(values)
    values.map do |column, value|
      equal_expression(column, value)
    end
  end

  def select_equal_expressions(values)
    values.map do |column, value|
      value.nil? ? "#{column} IS NULL" : equal_expression(column, value)
    end
  end

  def equal_expression(_column, _value)
    raise NotImplementedError, "#{self.class}#equal_expression not implemented"
  end
end
