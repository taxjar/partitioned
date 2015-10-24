require 'spec_helper'
require "#{File.dirname(__FILE__)}/../support/tables_spec_helper"
require "#{File.dirname(__FILE__)}/../support/shared_example_spec_helper_for_text_key"

module Partitioned

  describe ByTextField do

    include TablesSpecHelper

    module TextField
      class Employee < ByTextField
        include BulkDataMethods::Mixin
        
        belongs_to :company, :class_name => 'Company'

        def self.partition_text_field
          return :text_field
        end

        def self.normalized_text_values
          ['a','b','c','d']
        end

        partitioned do |partition|
          partition.index :text_field
        end
      end # Employee
    end # TextField

    before(:all) do
      @employee = TextField::Employee
      create_tables
      @employee.create_new_partition_tables(TextField::Employee.normalized_text_values)
      ActiveRecord::Base.connection.execute <<-SQL
        insert into employees_partitions.pa (company_id,name) values (1,'Keith');
      SQL
    end

    after(:all) do
      drop_tables
    end

    let(:class_by_id) { ::Partitioned::ByTextField }

    describe "model is abstract class" do

      it "returns true" do
        expect(class_by_id.abstract_class).to be_truthy
      end

    end # model is abstract class

    describe "#partition_text_field" do

      it "returns :id" do
        expect {
          class_by_id.partition_text_field
        }.to raise_error(MethodNotImplemented)
      end

    end # #partition_text_field

    describe "partitioned block" do

      context "checks if there is data in the indexes field" do

        it "returns :integer_field" do
          expect(class_by_id.configurator_dsl.data.indexes.first.call(@employee, nil).field).to eq(:text_field)
        end

        it "returns { :unique => true }" do
          expect(class_by_id.configurator_dsl.data.indexes.first.call(@employee, nil).options).to eq({})
        end

      end # checks if there is data in the indexes field

    end # partitioned block

    it_should_behave_like "check that basic operations with postgres works correctly for text key", TextField::Employee

  end # ByTextField

end # Partitioned