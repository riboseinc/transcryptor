# frozen_string_literal: true

require 'spec_helper'

ActiveRecord::Base.connection.create_table(:active_record_adapter_specs) do |t|
  t.string   :column_1
  t.integer  :column_2
end

class ActiveRecordAdapterSpec < ActiveRecord::Base; end

describe Transcryptor::ActiveRecord::Adapter do
  subject { described_class.new(ActiveRecord::Base.connection) }

  let(:model_class) { ActiveRecordAdapterSpec }

  before { 5.times { |i| model_class.create!(column_1: 'value', column_2: i) } }
  after { model_class.delete_all }

  describe '#select_rows' do
    it 'returns rows as an array of hashes' do
      rows = subject.select_rows('active_record_adapter_specs', ['column_1', 'column_2'])

      expect(rows.first).to eq({ 'column_1' => 'value', 'column_2' => 0 })
    end

    context 'with selection_criteria' do
      it 'restricts according to :where clause' do
        rows = subject.select_rows(
          'active_record_adapter_specs',
          ['column_1', 'column_2'],
          proc {
            "column_2 < 3"
          }
        )
        column_2s = rows.map { |row| row['column_2'] }
        expect(column_2s).to     include 0
        expect(column_2s).to     include 1
        expect(column_2s).to     include 2
        expect(column_2s).to_not include 3
        expect(column_2s).to_not include 4
        expect(column_2s).to_not include 5
      end
    end
  end

  describe '#update_row' do
    let(:active_record_adapter_spec) { model_class.first }

    it 'updates row with given values' do
      subject.update_row(
        'active_record_adapter_specs',
        { 'column_1' => 'value', 'column_2' => 0 },
        { 'column_1' => 'updated', 'column_2' => 2 },
      )

      expect(active_record_adapter_spec.column_1).to eq('updated')
      expect(active_record_adapter_spec.column_2).to eq(2)
    end

    context 'with previously NULL values' do
      let(:active_record_adapter_spec) { model_class.create!(column_1: nil, column_2: nil) }

      before do
        active_record_adapter_spec

        expect(active_record_adapter_spec.column_1).to be_nil
        expect(active_record_adapter_spec.column_2).to be_nil
      end

      it 'updates row with given values' do

        subject.update_row(
          'active_record_adapter_specs',
          { 'column_1' => nil, 'column_2' => nil },
          { 'column_1' => 'updated', 'column_2' => 2 },
        )

        active_record_adapter_spec.reload

        expect(active_record_adapter_spec.column_1).to eq('updated')
        expect(active_record_adapter_spec.column_2).to eq(2)
      end

    end

    it 'calls connection.exec_update with :name and :binds params' do
      expected_sql = "test sql statement"
      adapter      = subject

      allow(adapter).to receive(:update_query).and_return(expected_sql)
      expect(adapter.connection).to receive(:exec_update).with(expected_sql, "SQL", [])

      subject.update_row(
        'active_record_adapter_specs',
        { 'column_1' => 'value', 'column_2' => 1 },
        { 'column_1' => 'updated', 'column_2' => 2 },
      )
    end
  end
end
