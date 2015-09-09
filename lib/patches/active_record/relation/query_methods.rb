require 'active_record'
require 'active_record/relation/query_methods.rb'

module ActiveRecord

  module QueryMethods

    # This method is patched to use partition instead
    # of the parent table.
    def build_select(arel, selects)
      unless selects.empty?
        @implicit_readonly = false
        arel.project(*selects)
      else
        # ****** BEGIN PATCH ******
#         arel.project(@klass.arel_table[Arel.star])
        arel.project(table[Arel.star])
        # ****** END PATCH ******
      end
    end

  end # QueryMethods
   
end # ActiveRecord
