require 'active_record'
require 'active_record/persistence.rb'
#require 'active_record/relation/query_methods.rb'

# Patching {ActiveRecord} to allow certain partitioning (that related to the primary key) to work.
#
module ActiveRecord

  module Persistence
    # This method is patched to provide a relation referencing the partition instead
    # of the parent table.
    def relation_for_destroy
      pk         = self.class.primary_key
      column     = self.class.columns_hash[pk]
      substitute = self.class.connection.substitute_at(column, 0)

      # ****** BEGIN PATCH ******
      if self.class.respond_to?(:dynamic_arel_table)
        using_arel_table = dynamic_arel_table()
        relation = ActiveRecord::Relation.new(self.class, using_arel_table).
          where(using_arel_table[pk].eq(substitute))
      else
      # ****** END PATCH ******
      relation = self.class.unscoped.where(
        self.class.arel_table[pk].eq(substitute))
      # ****** BEGIN PATCH ******
      end
      # ****** END PATCH ******

      relation.bind_values = [[column, id]]
      relation
    end

    # This method is patched to prefetch the primary key (if necessary) and to ensure
    # that the partitioning attributes are always included (AR will exclude them
    # if the db column's default value is the same as the new record's value).
    def _create_record(attribute_names = @attributes.keys)
      # ****** BEGIN PATCH ******
      if self.id.nil? && self.class.respond_to?(:prefetch_primary_key?) && self.class.prefetch_primary_key?
        self.id = self.class.connection.next_sequence_value(self.class.sequence_name)
        attribute_names |= ["id"]
      end

      if self.class.respond_to?(:partition_keys)
        attribute_names |= self.class.partition_keys.map(&:to_s)
      end
      # ****** END PATCH ******
      attributes_values = arel_attributes_with_values_for_create(attribute_names)

      new_id = self.class.unscoped.insert attributes_values
      self.id ||= new_id if self.class.primary_key

      @new_record = false
      id
    end
   
  end # Persistence

end # ActiveRecord
