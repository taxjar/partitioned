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
  # Monkeypatch based on:
  # https://github.com/rails/rails/blob/5-2-stable/activerecord/lib/active_record/persistence.rb
  #
  module Persistence
    module ClassMethods
      # TODO: def _delete_record(constraints)

      def _insert_record(values) # :nodoc:
        primary_key_value = nil

        if primary_key && Hash === values
          primary_key_value = values[primary_key]

          if !primary_key_value && prefetch_primary_key?
            primary_key_value = next_sequence_value
            values[primary_key] = primary_key_value
          end
        end

        # ****** BEGIN PARTITIONED PATCH ******
        if self.respond_to?(:dynamic_arel_table)
          actual_arel_table = self.dynamic_arel_table(values).clone
        else
          actual_arel_table = arel_table.clone
        end
        actual_arel_table.table_alias = nil
        # ****** END PARTITIONED PATCH ******

        if values.empty?
          im = arel_table.compile_insert(connection.empty_insert_statement_value)
          im.into arel_table
        else
          im = arel_table.compile_insert(_substitute_values(values))
        end

        # ****** BEGIN PARTITIONED PATCH ******
        im.ast.relation = actual_arel_table
        # ****** END PARTITIONED PATCH ******

        connection.insert(im, "#{self} Create", primary_key || false, primary_key_value)
      end

      def _update_record(values, constraints) # :nodoc:
        constraints = _substitute_values(constraints).map { |attr, bind| attr.eq(bind) }

        # ****** BEGIN PARTITIONED PATCH ******
        if self.respond_to?(:dynamic_arel_table)
          actual_arel_table = self.dynamic_arel_table(values).clone
        else
          actual_arel_table = arel_table.clone
        end

        um = actual_arel_table.where(
          constraints.reduce(&:and)
        ).compile_update(_substitute_values(values), primary_key)

        actual_arel_table.table_alias = arel_table.name
        um.ast.relation = actual_arel_table
        # ****** END PARTITIONED PATCH ******

        connection.update(um, "#{self} Update")
      end

      private

    end

    private

    def _create_record(attribute_names = self.attribute_names)
      # ****** BEGIN PARTITIONED PATCH ******
      if self.id.nil? && self.class.respond_to?(:prefetch_primary_key?) && self.class.prefetch_primary_key?
        self.id = self.class.connection.next_sequence_value(self.class.sequence_name)
        attribute_names |= ["id"]
      end

      if self.class.respond_to?(:partition_keys)
        attribute_names |= self.class.partition_keys.map(&:to_s)
      end
      # ****** END PARTITIONED PATCH ******

      attributes_values = attributes_with_values_for_create(attribute_names)

      new_id = self.class._insert_record(attributes_values)
      self.id ||= new_id if self.class.primary_key

      @new_record = false

      yield(self) if block_given?

      id
    end

    def _update_record(attribute_names = self.attribute_names)
      # ****** BEGIN PARTITIONED PATCH ******
      if self.class.respond_to?(:partition_keys)
        attribute_names.concat self.class.partition_keys.map(&:to_s)
        attribute_names.uniq!
      end
      # ****** END PARTITIONED PATCH ******

      attributes_names = attributes_for_update(attribute_names)
      if attributes_names.empty?
        affected_rows = 0
        @_trigger_update_callback = true
      else
        affected_rows = _update_row(attribute_names)
        @_trigger_update_callback = affected_rows == 1
      end

      yield(self) if block_given?

      affected_rows
    end
  end
end
