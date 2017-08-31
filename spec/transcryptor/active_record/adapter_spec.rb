# frozen_string_literal: true

require 'spec_helper'

ActiveRecord::Base.connection.create_table(:active_record_adapter_specs) do |t|
  t.string   :column_1
  t.integer  :column_2
end

class ActiveRecordAdapterSpec < ActiveRecord::Base; end

describe Transcryptor::ActiveRecord::Adapter do
  subject { described_class.new(ActiveRecord::Base.connection) }

  before { ActiveRecordAdapterSpec.create!(column_1: 'value', column_2: 1) }
  after { ActiveRecordAdapterSpec.delete_all }

  describe '#select_rows' do
    it 'returns rows as an array of hashes' do
      rows = subject.select_rows('active_record_adapter_specs', ['column_1', 'column_2'])

      expect(rows).to eq([{ 'column_1' => 'value', 'column_2' => 1 }])
    end
  end

  describe '#update_row' do
    let(:active_record_adapter_spec) { ActiveRecordAdapterSpec.first }

    it 'updates row with given values' do
      subject.update_row(
        'active_record_adapter_specs',
        { 'column_1' => 'value', 'column_2' => 1 },
        { 'column_1' => 'updated', 'column_2' => 2 }
      )

      expect(active_record_adapter_spec.column_1).to eq('updated')
      expect(active_record_adapter_spec.column_2).to eq(2)
    end

    it 'calls connection.exec_update with :name and :binds params' do
      expected_sql = "test sql statement"
      adapter      = subject

      allow(adapter).to receive(:update_query).and_return(expected_sql)
      expect(adapter.connection).to receive(:exec_update).with(expected_sql, "SQL", [])

      subject.update_row(
        'active_record_adapter_specs',
        { 'column_1' => 'value', 'column_2' => 1 },
        { 'column_1' => 'updated', 'column_2' => 2 }
      )
    end
  end
end
