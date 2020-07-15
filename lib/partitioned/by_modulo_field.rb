module Partitioned

  # Partition tables by by modulo of an modulo field.
  #
  class ByModuloField < PartitionedBase

    self.abstract_class = true

    # the modulus used to partion modulo field by
    # @return [Integer] how partions to partion into
    #
    def self.partition_modulus
      return 96
    end

    # the name of the partition key field
    # @return [String] the name of the field
    #
    def self.partition_modulo_field
      raise MethodNotImplemented.new(self, :partition_modulo_field)
    end

    # the normalized key value for a given key value
    # @return [Integer] the normalized value
    #
    def self.partition_normalize_key_value(modulo_field_value)
      return modulo_field_value.to_i % self.partition_modulus
    end

    # Range generation provided for methods like created_infrastructure that need a set of partition key values
    # to operate on.
    #
    # @param [Object] start_value the first value to generate the range from
    # @param [Object] end_value the last value to generate the range from
    # @param [Object] step (1) number of values to advance.
    # @return [Enumerable] the range generated
    #
    def self.partition_generate_range(start_value=0, end_value=partition_modulus-1, step=1)
      return Range.new(start_value, end_value).step(step)
    end

    partitioned do |partition|
      partition.on lambda {|model| return model.partition_modulo_field }

      partition.index lambda {|model, field|
        return Configurator::Data::Index.new(model.partition_modulo_field, {})
      }

      partition.order "substring(tablename, 2)::integer desc"

      partition.check_constraint lambda { |model, id|
        value = model.partition_normalize_key_value(id)
        return "(#{model.partition_modulo_field}::integer % #{model.partition_modulus}) = #{value}::integer"
      }

    end

  end # ByModuloField

end # Partitioned