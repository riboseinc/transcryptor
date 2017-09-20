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

  let(:model_class) { DataMapperAdapterSpec }

  before { 5.times { |i| model_class.create!(column_1: 'value', column_2: i) } }
  after { model_class.destroy }

  describe '#select_rows' do
    it 'returns rows as an array of hashes' do
      rows = subject.select_rows('data_mapper_adapter_specs', ['column_1', 'column_2'])

      expect(rows.first).to eq({ 'column_1' => 'value', 'column_2' => 0 })
    end

    context 'with selection_criteria' do
      it 'restricts according to :where clause' do
        rows = subject.select_rows(
          'data_mapper_adapter_specs',
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
    let(:data_mapper_adapter_spec) { model_class.first }

    it 'updates row with given values' do
      subject.update_row(
        'data_mapper_adapter_specs',
        { 'column_1' => 'value', 'column_2' => 0 },
        { 'column_1' => 'updated', 'column_2' => 2 }
      )

      expect(data_mapper_adapter_spec.column_1).to eq('updated')
      expect(data_mapper_adapter_spec.column_2).to eq(2)
    end

    context 'with previously NULL values' do
      let(:data_mapper_adapter_spec) { model_class.create!(column_1: nil, column_2: nil) }

      before do
        data_mapper_adapter_spec

        expect(data_mapper_adapter_spec.column_1).to be_nil
        expect(data_mapper_adapter_spec.column_2).to be_nil
      end

      it 'updates row with given values' do

        subject.update_row(
          'data_mapper_adapter_specs',
          { 'column_1' => nil, 'column_2' => nil },
          { 'column_1' => 'updated', 'column_2' => 2 },
        )

        data_mapper_adapter_spec.reload

        expect(data_mapper_adapter_spec.column_1).to eq('updated')
        expect(data_mapper_adapter_spec.column_2).to eq(2)
      end

    end
  end
end
