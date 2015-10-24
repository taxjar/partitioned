module Partitioned

  # Partition tables by a text field.
  #
  class ByTextField < PartitionedBase

    self.abstract_class = true

    # the name of the partition key field
    # @return [String] the name of the field
    #
    def self.partition_text_field
      raise MethodNotImplemented.new(self, :partition_text_field)
    end

    # the normalized key value for a given key value
    # @return [Integer] the normalized value
    #
    def self.partition_normalize_key_value(text_field_value)
      return text_field_value.to_s.gsub(' ', '_').downcase
    end

    # the normalized key value for a given key value
    # @return [Integer] the normalized value
    #
    def self.normalized_text_values
      raise MethodNotImplemented.new(self, :partition_text_field)
    end

    # Range generation provided for methods like created_infrastructure that need a set of partition key values
    # to operate on.
    #
    # @return [Enumerable] the array generated
    #
    def self.partition_generate_range
      return self.normalized_text_values
    end

    partitioned do |partition|
      partition.on lambda {|model| return model.partition_text_field }

      partition.index lambda {|model, field|
        return Configurator::Data::Index.new(model.partition_text_field, {})
      }

      partition.order "substring(tablename, 2)::text desc"

      partition.check_constraint lambda { |model, id|
        value = model.partition_normalize_key_value(id).upcase
        return "#{model.partition_text_field}::text = '#{value}'::text"
      }

    end

  end # ByTextField

end # Partitioned