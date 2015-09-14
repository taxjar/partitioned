require 'spec_helper'
require "#{File.dirname(__FILE__)}/../support/tables_spec_helper"
require "#{File.dirname(__FILE__)}/../support/shared_example_spec_helper_for_modulo_key"

module Partitioned

  describe ByModuloField do

    include TablesSpecHelper

    module ModuloField
      class Employee < ByModuloField
        include BulkDataMethods::Mixin
        
        belongs_to :company, :class_name => 'Company'

        def self.partition_modulus
          return 2
        end

        def self.partition_modulo_field
          return :integer_field
        end

        partitioned do |partition|
          partition.index :integer_field
        end
      end # Employee
    end # ModuloField

    before(:all) do
      @employee = ModuloField::Employee
      create_tables
      @employee.create_new_partition_tables(Range.new(0, 1))
      ActiveRecord::Base.connection.execute <<-SQL
        insert into employees_partitions.p1 (company_id,name) values (1,'Keith');
      SQL
    end

    after(:all) do
      drop_tables
    end

    let(:class_by_id) { ::Partitioned::ByModuloField }

    describe "model is abstract class" do

      it "returns true" do
        expect(class_by_id.abstract_class).to be_truthy
      end

    end # model is abstract class

    describe "#partition_modulo_field" do

      it "returns :id" do
        expect {
          class_by_id.partition_modulo_field
        }.to raise_error(MethodNotImplemented)
      end

    end # #partition_modulo_field

    describe "partitioned block" do

      context "checks if there is data in the indexes field" do

        it "returns :integer_field" do
          expect(class_by_id.configurator_dsl.data.indexes.first.call(@employee, nil).field).to eq(:integer_field)
        end

        it "returns { :unique => true }" do
          expect(class_by_id.configurator_dsl.data.indexes.first.call(@employee, nil).options).to eq({})
        end

      end # checks if there is data in the indexes field

    end # partitioned block

    it_should_behave_like "check that basic operations with postgres works correctly for modulo key", ModuloField::Employee

  end # ByModuloField

end # Partitioned