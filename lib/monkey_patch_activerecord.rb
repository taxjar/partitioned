require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/relation.rb'
require 'active_record/persistence.rb'
require 'active_record/relation/query_methods.rb'

#
# Patching {ActiveRecord} to allow specifying the table name as a function of
# attributes.
#
module ActiveRecord
  #
  # Patches for Persistence to allow certain partitioning (that related to the primary key) to work.
  #
  module Persistence
    # This method is patched to provide a relation referencing the partition instead
    # of the parent table.
    def relation_for_destroy
      pk         = self.class.primary_key
      column     = self.class.columns_hash[pk]
      substitute = self.class.connection.substitute_at(column, 0)

      # ****** BEGIN PARTITIONED PATCH ******
      if self.class.respond_to?(:dynamic_arel_table)
        using_arel_table = dynamic_arel_table()
        relation = ActiveRecord::Relation.new(self.class, using_arel_table).
          where(using_arel_table[pk].eq(substitute))
      else
        # ****** END PARTITIONED PATCH ******
        relation = self.class.unscoped.where(
                                             self.class.arel_table[pk].eq(substitute))
        # ****** BEGIN PARTITIONED PATCH ******
      end
      # ****** END PARTITIONED PATCH ******

      relation.bind_values = [[column, id]]
      relation
    end

    # This method is patched to prefetch the primary key (if necessary) and to ensure
    # that the partitioning attributes are always included (AR will exclude them
    # if the db column's default value is the same as the new record's value).
    def _create_record(attribute_names = @attributes.keys)
      # ****** BEGIN PARTITIONED PATCH ******
      if self.id.nil? && self.class.respond_to?(:prefetch_primary_key?) && self.class.prefetch_primary_key?
        self.id = self.class.connection.next_sequence_value(self.class.sequence_name)
        attribute_names |= ["id"]
      end

      if self.class.respond_to?(:partition_keys)
        attribute_names |= self.class.partition_keys.map(&:to_s)
      end
      # ****** END PARTITIONED PATCH ******

      attributes_values = arel_attributes_with_values_for_create(attribute_names)

      new_id = self.class.unscoped.insert attributes_values
      self.id ||= new_id if self.class.primary_key

      @new_record = false
      id
    end

    # Updates the associated record with values matching those of the instance attributes.
    # Returns the number of affected rows.
    # NOTE(hofer): This monkeypatch intended for activerecord 4.0.  Based on this code:
    # https://github.com/rails/rails/blob/4-0-stable/activerecord/lib/active_record/persistence.rb#L487
    def _update_record(attribute_names = @attributes.keys)
      attributes_with_values = arel_attributes_with_values_for_update(attribute_names)
      if attributes_with_values.empty?
        0
      else
        klass = self.class
        column_hash = klass.connection.schema_cache.columns_hash klass.table_name
        db_columns_with_values = attributes_with_values.map { |attr,value|
          real_column = column_hash[attr.name]
          [real_column, value]
        }
        bind_attrs = attributes_with_values.dup
        bind_attrs.keys.each_with_index do |column, i|
          real_column = db_columns_with_values[i].first
          bind_attrs[column] = klass.connection.substitute_at(real_column, i)
        end

        # ****** BEGIN PARTITIONED PATCH ******
        if self.respond_to?(:dynamic_arel_table)
          using_arel_table = dynamic_arel_table()
          stmt = klass.unscoped.where(using_arel_table[klass.primary_key].eq(id_was || id)).arel.compile_update(bind_attrs)

          # NOTE(hofer): The stmt variable got set up using
          # klass.arel_table as its arel value.  So arel_table.name is
          # what gets used to construct the update statement.  Here we
          # set it to the specific partition name for this record so
          # that the update gets run just on that partition, not on
          # the parent one (which can cause performance issues).
          begin
            klass.arel_table.name = partition_table_name()
            klass.connection.update stmt, 'SQL', db_columns_with_values
          ensure
            klass.arel_table.name = klass.table_name
          end
        else
          # Original lines:
          stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id_was || id)).arel.compile_update(bind_attrs)
          klass.connection.update stmt, 'SQL', db_columns_with_values
        end
        # ****** END PARTITIONED PATCH ******
      end
    end

  end # module Persistence

  module QueryMethods

    # This method is patched to change the default behavior of select
    # to use the Relation's Arel::Table
    def build_select(arel, selects)
      if !selects.empty?
        expanded_select = selects.map do |field|
          columns_hash.key?(field.to_s) ? arel_table[field] : field
        end
        arel.project(*expanded_select)
      else
        # ****** BEGIN PARTITIONED PATCH ******
        # Original line:
        # arel.project(@klass.arel_table[Arel.star])
        arel.project(table[Arel.star])
        # ****** END PARTITIONED PATCH ******
      end
    end

  end # module QueryMethods

  class Relation

    # This method is patched to use a table name that is derived from
    # the attribute values.
    def insert(values)
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

      # ****** BEGIN PARTITIONED PATCH ******
      actual_arel_table = @klass.dynamic_arel_table(Hash[*values.map{|k,v| [k.name,v]}.flatten]) if @klass.respond_to?(:dynamic_arel_table)
      actual_arel_table = @table unless actual_arel_table
      # Original line:
      # im.into @table
      im.into actual_arel_table
      # ****** END PARTITIONED PATCH ******

      conn = @klass.connection

      substitutes = values.sort_by { |arel_attr,_| arel_attr.name }
      binds       = substitutes.map do |arel_attr, value|
        [@klass.columns_hash[arel_attr.name], value]
      end

      substitutes.each_with_index do |tuple, i|
        tuple[1] = conn.substitute_at(binds[i][0], i)
      end

      if values.empty? # empty insert
        im.values = Arel.sql(connection.empty_insert_statement_value)
      else
        im.insert substitutes
      end

      conn.insert(
                  im,
                  'SQL',
                  primary_key,
                  primary_key_value,
                  nil,
                  binds)
    end

  end # class Relation
end # module ActiveRecord
