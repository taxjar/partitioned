module ForeignKeySpecHelper

  def foreign_key_exists?(from_schema:, from_table:, from_column:, to_table:, to_column:)
    conn = ActiveRecord::Base.connection
    conn.select_value(
      <<~SQL
        SELECT EXISTS (
          SELECT 1
          FROM  information_schema.table_constraints
          JOIN information_schema.key_column_usage
            ON table_constraints.constraint_name = key_column_usage.constraint_name
            AND table_constraints.constraint_schema = key_column_usage.constraint_schema
            AND table_constraints.table_schema = key_column_usage.table_schema
            AND table_constraints.table_name = key_column_usage.table_name
          JOIN information_schema.constraint_column_usage
            ON table_constraints.constraint_name = constraint_column_usage.constraint_name
            AND table_constraints.constraint_schema = constraint_column_usage.constraint_schema
          WHERE
            table_constraints.constraint_type = 'FOREIGN KEY'
            AND table_constraints.table_schema = '#{conn.quote_string(from_schema)}'
            AND table_constraints.table_name = '#{conn.quote_string(from_table)}'
            AND key_column_usage.column_name = '#{conn.quote_string(from_column)}'
            AND constraint_column_usage.table_schema = current_schema() -- to_table's schema
            AND constraint_column_usage.table_name = '#{conn.quote_string(to_table)}'
            AND constraint_column_usage.column_name = '#{conn.quote_string(to_column)}'
        )
      SQL
    )
  end

end