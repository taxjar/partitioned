require 'spec_helper'
require "#{File.dirname(__FILE__)}/../support/tables_spec_helper"
require "#{File.dirname(__FILE__)}/../support/shared_example_spec_helper_for_time_key"

module Partitioned

  describe ByCreatedAt do

    include TablesSpecHelper

    module CreatedAt
      class Employee < Partitioned::ByCreatedAt
        belongs_to :company, :class_name => 'Company'

        partitioned do |partition|
          partition.index :id, :unique => true
          partition.foreign_key :company_id
        end
      end # Employee
    end # CreatedAt

    before(:all) do
      @employee = CreatedAt::Employee
      create_tables
      dates = @employee.partition_generate_range(DATE_NOW,
                                                 DATE_NOW + 3.weeks)
      @employee.create_new_partition_tables(dates)
      ActiveRecord::Base.connection.execute <<-SQL
        insert into employees_partitions.
          p#{DATE_NOW.at_beginning_of_week.strftime('%Y%m%d')}
          (company_id,name) values (1,'Keith');
      SQL
    end

    after(:all) do
      drop_tables
    end

    let(:class_by_created_at) { ::Partitioned::ByCreatedAt }

    describe "model is abstract class" do

      it "returns true" do
        expect(class_by_created_at.abstract_class).to be_truthy
      end

    end # model is abstract class

    describe "multi threads" do
      context 'update' do
        it do
          employee = CreatedAt::Employee.first
          employee2 = CreatedAt::Employee.create!(company_id: 1, name: 'Robert', created_at: 2.weeks.from_now)

          update_method = Partitioned::CreatedAt::Employee.connection.method(:update)
          allow(Partitioned::CreatedAt::Employee.connection).to receive(:update) do |um, msg|
            sleep 0.1
            update_method.call(um, msg)
          end

          thread1 = Thread.new do
            employee2.name = 'Robert2'
            employee2.save!
          end

          sleep 0.1
          employee.name = 'Keith2'
          employee.save!

          expect(employee.reload.name).to eq 'Keith2'
          expect(employee2.reload.name).to eq 'Robert2'

          thread1.join

        end
      end

      context 'insert' do
        it do
          insert_method = Partitioned::CreatedAt::Employee.connection.method(:insert)
          allow(Partitioned::CreatedAt::Employee.connection).to receive(:insert) do |im, msg, p_k, p_k_v|
            sleep 0.1
            insert_method.call(im, msg, p_k, p_k_v)
          end

          expect do
            thread1 = Thread.new do
              CreatedAt::Employee.create!(company_id: 1, name: 'Robert', created_at: 1.weeks.from_now)
            end

            sleep 0.1
            CreatedAt::Employee.create!(company_id: 1, name: 'Przemek', created_at: 2.weeks.from_now)

            thread1.join
          end.not_to raise_error
        end
      end
    end # multi threads

    describe "#partition_time_field" do

      it "returns :created_at" do
        expect(class_by_created_at.partition_time_field).to eq(:created_at)
      end

    end # #partition_time_field

    it_should_behave_like "check that basic operations with postgres works correctly for time key", CreatedAt::Employee

  end # ByCreatedAt

end # Partitioned
