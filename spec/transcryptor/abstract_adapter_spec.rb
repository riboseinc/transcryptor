require 'spec_helper'

describe Transcryptor::AbstractAdapter do
  subject { described_class.new(connection) }

  let(:connection) { double(:connection) }

  describe '#select_rows' do
    it 'raises NotImplementedError' do
      expect{
        subject.select_rows('table_name', { 'column' => 'value' })
      }.to raise_error(NotImplementedError, "#{described_class}#select_rows not implemented")
    end
  end

  describe '#update_row' do
    it 'raises NotImplementedError' do
      expect{
        subject.update_row('table_name', { 'column' => 'old_value' }, { 'column' => 'new_value' })
      }.to raise_error(NotImplementedError, "#{described_class}#update_row not implemented")
    end
  end
end
