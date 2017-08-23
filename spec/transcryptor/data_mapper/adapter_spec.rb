# frozen_string_literal: true

require 'spec_helper'

class DataMapperAdapterSpec
  include DataMapper::Resource

  property :id,       Serial
  property :column_1, String
  property :column_2, Integer
end

DataMapper.finalize
DataMapper.auto_migrate!

describe Transcryptor::DataMapper::Adapter do
  subject { described_class.new(DataMapper.repository.adapter) }

  before { DataMapperAdapterSpec.create!(column_1: 'value', column_2: 1) }
  after { DataMapperAdapterSpec.destroy }

  describe '#select_rows' do
    it 'returns rows as an array of hashes' do
      rows = subject.select_rows('data_mapper_adapter_specs', ['column_1', 'column_2'])
      expect(rows).to eq([{ 'column_1' => 'value', 'column_2' => 1 }])
    end
  end

  describe '#update_row' do
    let(:data_mapper_adapter_spec) { DataMapperAdapterSpec.first }

    it 'updates row with given values' do
      subject.update_row(
        'data_mapper_adapter_specs',
        { 'column_1' => 'value', 'column_2' => 1 },
        { 'column_1' => 'updated', 'column_2' => 2 }
      )

      expect(data_mapper_adapter_spec.column_1).to eq('updated')
      expect(data_mapper_adapter_spec.column_2).to eq(2)
    end
  end
end
