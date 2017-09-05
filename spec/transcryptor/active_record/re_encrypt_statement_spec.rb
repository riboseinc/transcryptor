# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

ActiveRecord::Base.connection.create_table(:active_record_re_encrypt_statement_specs) do |t|
  t.integer  :lucky_integer, default: 7
  t.string   :encrypted_column_1
  t.string   :encrypted_column_1_iv
end

class ActiveRecordReEncryptStatementSpec < ActiveRecord::Base
  attr_encrypted :column_1, key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe'
end

describe Transcryptor::ActiveRecord::ReEncryptStatement do

  let(:migration) do
    Kernel.const_set(
      :"Migration#{SecureRandom.hex(4)}",
      Class.new(ActiveRecord::Migration),
    )
  end

  before do
    allow(migration).to receive(:up) do
      migration.instance_exec(up_params) do |params|
        re_encrypt_column(*params)
      end
    end

    allow(migration).to receive(:down) do
      migration.instance_exec(down_params) do |params|
        re_encrypt_column(*params)
      end
    end

    migration.migrate(:up)
    ActiveRecordReEncryptStatementSpec.encrypted_attributes[:column_1][:key] = new_key
  end

  let(:expected_value) { 'my_value' }
  let!(:record) { ActiveRecordReEncryptStatementSpec.create!(column_1: expected_value) }

  after do
    migration.migrate(:down)
    ActiveRecordReEncryptStatementSpec.delete_all
  end

  context 'with no extra columns specified' do

    let(:new_key) { '2asd2asd2asd2asd2asd2asd2asd2asd' }

    let(:up_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
        { key: new_key },
      ]
    end

    let(:down_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: new_key },
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
      ]
    end

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      expect(record.reload.column_1).to eq(expected_value)
    end
  end

  context 'with extra columns specified' do

    let(:new_key) { '7asd7asd7asd7asd7asd7asd7asd7asd' }

    let(:up_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
        { key: ->(o) { '2asd2asd2asd2asd2asd2asd2asd2asd'.gsub(/2/, o.lucky_integer.to_s) } },
        %i[lucky_integer],
      ]
    end

    let(:down_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: ->(o) { new_key } },
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
        %i[lucky_integer],
      ]
    end

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      expect(record.reload.column_1).to eq(expected_value)
    end
  end
end
