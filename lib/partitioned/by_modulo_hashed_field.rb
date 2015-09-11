module Partitioned

  # Partition tables by by modulo of a hashed modulo field.
  #
  class ByModuloHashedField < ByModuloField

    self.abstract_class = true

    # the normalized key value for a given key value
    # @return [Integer] the normalized value
    #
    def self.partition_normalize_key_value(modulo_field_value)
      return Digest::MD5.hexdigest(modulo_field_value.to_s).last(8).to_i(16)  % self.partition_modulus
    end

    partitioned do |partition|
      partition.index lambda {|model, field|
        return Configurator::Data::Index.new(model.partition_modulo_field, {})
      }
    end

  end # ByModuloHashedField

end # Partitioned