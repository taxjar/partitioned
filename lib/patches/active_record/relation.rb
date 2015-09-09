require 'active_record'
require 'active_record/relation.rb'

# Patching to allow Patches to allow certain partitioning (that are related to the primary key) to work.
#
module ActiveRecord

  class Relation
    
    # This method is patched to use a table name that is derived from
    # the attribute values.
    def insert(values) # :nodoc:
      primary_key_value = nil

      if primary_key && Hash === values
        primary_key_value = values[values.keys.find { |k|
          k.name == primary_key
        }]

        if !primary_key_value && connection.prefetch_primary_key?(klass.table_name)
          primary_key_value = connection.next_sequence_value(klass.sequence_name)
          values[klass.arel_table[klass.primary_key]] = primary_key_value
        end
      end

      im = arel.create_insert
      # ****** BEGIN PATCH ******
      actual_arel_table = @klass.dynamic_arel_table(Hash[*values.map{|k,v| [k.name,v]}.flatten]) if @klass.respond_to?(:dynamic_arel_table)
      actual_arel_table = @table unless actual_arel_table
      #im.into @table
      im.into actual_arel_table
      # ****** END PATCH ******

      substitutes, binds = substitute_values values

      if values.empty? # empty insert
        im.values = Arel.sql(connection.empty_insert_statement_value)
      else
        im.insert substitutes
      end

      @klass.connection.insert(
        im,
        'SQL',
        primary_key,
        primary_key_value,
        nil,
        binds)
    end

  end # Relation

end # ActiveRecord
