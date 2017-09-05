# frozen_string_literal: true

require 'spec_helper'

ActiveRecord::Base.connection.create_table(:active_record_re_encrypt_statement_specs) do |t|
  t.integer  :lucky_integer, default: 7
  t.string   :encrypted_column_1
  t.string   :encrypted_column_1_iv
end

class ActiveRecordReEncryptStatementSpec < ActiveRecord::Base
  attr_encrypted :column_1, key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe'
end

class ReEncryptActiveRecordReEncryptStatementSpecColumn1 < ActiveRecord::Migration
  def up
    re_encrypt_column(
      :active_record_re_encrypt_statement_specs,
      :column_1,
      { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
      { key: '2asd2asd2asd2asd2asd2asd2asd2asd' },
    )
  end

  def down
    re_encrypt_column(
      :active_record_re_encrypt_statement_specs,
      :column_1,
      { key: '2asd2asd2asd2asd2asd2asd2asd2asd' },
      { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
    )
  end
end

class ReEncryptActiveRecordReEncryptStatementSpecColumn1WithExtraColumns < ActiveRecord::Migration
  def up
    re_encrypt_column(
      :active_record_re_encrypt_statement_specs,
      :column_1,
      { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
      { key: ->(o) { '2asd2asd2asd2asd2asd2asd2asd2asd'.gsub(/2/, o.lucky_integer.to_s) } },
      %i[lucky_integer]
    )
  end

  def down
    re_encrypt_column(
      :active_record_re_encrypt_statement_specs,
      :column_1,
      { key: ->(o) { '2asd2asd2asd2asd2asd2asd2asd2asd'.gsub(/2/, o.lucky_integer.to_s) } },
      { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
      %i[lucky_integer]
    )
  end
end

describe Transcryptor::ActiveRecord::ReEncryptStatement do
  before do
    migration.migrate(:up)
    ActiveRecordReEncryptStatementSpec.encrypted_attributes[:column_1][:key] = new_key
  end

  after do
    migration.migrate(:down)
    ActiveRecordReEncryptStatementSpec.delete_all
  end

  let(:expected_value) { 'my_value' }

  context 'with no extra columns specified' do
    let!(:record)   { ActiveRecordReEncryptStatementSpec.create!(column_1: expected_value) }
    let(:migration) { ReEncryptActiveRecordReEncryptStatementSpecColumn1 }
    let(:new_key)   { '2asd2asd2asd2asd2asd2asd2asd2asd' }

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      expect(record.reload.column_1).to eq(expected_value)
    end
  end

  context 'with extra columns specified' do
    let!(:record)   { ActiveRecordReEncryptStatementSpec.create!(column_1: expected_value) }
    let(:migration) { ReEncryptActiveRecordReEncryptStatementSpecColumn1WithExtraColumns }
    let(:new_key)   { '7asd7asd7asd7asd7asd7asd7asd7asd' }

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      expect(record.reload.column_1).to eq(expected_value)
    end
  end
end
