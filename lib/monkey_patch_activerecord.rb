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
      def _insert_record(values, curr_arel_table = nil) # :nodoc:
        primary_key = self.primary_key
        primary_key_value = nil

        if primary_key && Hash === values
          primary_key_value = values[primary_key]

          if !primary_key_value && prefetch_primary_key?
            primary_key_value = next_sequence_value
            values[primary_key] = primary_key_value
          end
        end

        tmp_arel_table = curr_arel_table || arel_table

        if values.empty?
          im = tmp_arel_table.compile_insert(connection.empty_insert_statement_value(primary_key))
          im.into tmp_arel_table
        else
          im = tmp_arel_table.compile_insert(_substitute_values(values,tmp_arel_table))
        end

        connection.insert(im, "#{self} Create", primary_key || false, primary_key_value)
      end

      def _update_record(values, constraints, curr_arel_table = nil) # :nodoc:
        tmp_arel_table = curr_arel_table || arel_table
        constraints = _substitute_values(constraints, tmp_arel_table).map { |attr, bind| attr.eq(bind) }
        um = tmp_arel_table.where(
          constraints.reduce(&:and)
        ).compile_update(_substitute_values(values, tmp_arel_table), primary_key)

        connection.update(um, "#{self} Update")
      end

      def _delete_record(constraints, curr_arel_table = nil) # :nodoc:
        tmp_arel_table = curr_arel_table || arel_table
        constraints = _substitute_values(constraints, tmp_arel_table).map { |attr, bind| attr.eq(bind) }

        dm = Arel::DeleteManager.new
        dm.from(tmp_arel_table)
        dm.wheres = constraints

        connection.delete(dm, "#{self} Destroy")
      end

      def _substitute_values(values, tmp_arel_table = nil)
        curr_arel_table = tmp_arel_table || arel_table
        values.map do |name, value|
          attr = curr_arel_table[name]
          bind = predicate_builder.build_bind_attribute(attr.name, value)
          [attr, bind]
        end
      end
    end # module ClassMethods

    #TODO: real monkey patch
    def _update_row(attribute_names, attempted_action = "update")
      #begin monkey patch
      self.class._update_record(
        attributes_with_values(attribute_names),
        {@primary_key => id_in_database},
        self.respond_to?(:dynamic_arel_table) ? self.dynamic_arel_table : nil
      )
      #end monkey patch
    end

    def _create_record(attribute_names = self.attribute_names)
        attribute_names = attributes_for_create(attribute_names)
  
        #begin monkey patch
        new_id = self.class._insert_record(
          attributes_with_values(attribute_names),
          self.respond_to?(:dynamic_arel_table) ? self.dynamic_arel_table : nil
        )
        #end monkey patch
        self.id ||= new_id if @primary_key
  
        @new_record = false
        @previously_new_record = true
  
        yield(self) if block_given?
  
        id
    end

    def _delete_row
      #begin monkey patch
      self.class._delete_record(
        {@primary_key => id_in_database},
        self.respond_to?(:dynamic_arel_table) ? self.dynamic_arel_table : nil
      )
      #end monkey patch
    end
    

  end # module Persistence
end # module ActiveRecord
