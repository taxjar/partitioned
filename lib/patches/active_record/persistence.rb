require 'active_record'
require 'active_record/persistence.rb'

module ActiveRecord

  module Persistence

    # This method is patched to provide a relation referencing the partition instead
    # of the parent table.
    def destroy
      destroy_associations

      if persisted?
        IdentityMap.remove(self) if IdentityMap.enabled?
        pk         = self.class.primary_key
        column     = self.class.columns_hash[pk]
        substitute = connection.substitute_at(column, 0)

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
        relation.delete_all
      end

      @destroyed = true
      freeze
    end

    # This method is patched to provide a relation referencing the partition instead
    # of the parent table.
    def update(attribute_names = @attributes.keys)
      attributes_with_values = arel_attributes_values(false, false, attribute_names)
      return 0 if attributes_with_values.empty?
      klass = self.class
      # ****** BEGIN PATCH ******
      if self.class.respond_to?(:dynamic_arel_table)
        using_arel_table = dynamic_arel_table()
        stmt = klass.unscoped.where(using_arel_table[klass.primary_key].eq(id)).arel.compile_update(attributes_with_values)
      else
      # ****** END PATCH ******
      stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id)).arel.compile_update(attributes_with_values)
      # ****** BEGIN PATCH ******
      end
      # ****** END PATCH ******
      klass.connection.update stmt
    end

    # This method is patched to prefetch the primary key if needed
    #
    def create
      # ****** BEGIN PATCH ******
      if self.id.nil? && self.class.respond_to?(:prefetch_primary_key?) && self.class.prefetch_primary_key?
        self.id = connection.next_sequence_value(self.class.sequence_name)
      end
      # ****** END PATCH ******
      attributes_values = arel_attributes_values(!id.nil?)

      new_id = self.class.unscoped.insert attributes_values

      self.id ||= new_id if self.class.primary_key

      IdentityMap.add(self) if IdentityMap.enabled?
      @new_record = false
      id
    end
   
  end # Persistence

end # ActiveRecord
