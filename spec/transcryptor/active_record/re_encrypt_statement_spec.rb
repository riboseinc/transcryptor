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
  let(:record) { ActiveRecordReEncryptStatementSpec.create!(column_1: expected_value) }

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
        { key: new_key }
      ]
    end
    let(:down_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: new_key },
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' }
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
        extra_columns: %i[lucky_integer],
      ]
    end
    let(:down_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: ->(o) { new_key } },
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
        extra_columns: %i[lucky_integer],
      ]
    end

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      expect(record.reload.column_1).to eq(expected_value)
    end
  end

  context 'with extra columns and hooks specified' do
    let(:before_decrypt_probe)  { spy(:before_decrypt_probe)  }
    let(:after_encrypt_probe) { spy(:after_encrypt_probe) }
    let(:new_key) { '7asd7asd7asd7asd7asd7asd7asd7asd' }
    let(:up_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
        { key: ->(o) { '2asd2asd2asd2asd2asd2asd2asd2asd'.gsub(/2/, o.lucky_integer.to_s) } },
        extra_columns: %i[lucky_integer],
        before_decrypt:  -> (old_row, decryptor_class) { before_decrypt_probe.call(old_row, decryptor_class) },
        after_encrypt: -> (new_row, encryptor_class) { after_encrypt_probe.call(new_row, encryptor_class) }
      ]
    end
    let(:down_params) do
      [
        :active_record_re_encrypt_statement_specs,
        :column_1,
        { key: ->(o) { new_key } },
        { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
        extra_columns: %i[lucky_integer]
      ]
    end

    it 'calls before_decrypt hook' do
      expect(before_decrypt_probe).to have_received(:call).with(
        hash_including(:column_1),
        kind_of(Class)
      ).exactly(ActiveRecordReEncryptStatementSpec.count).times
    end

    it 'calls after_encrypt hook' do
      expect(after_encrypt_probe).to have_received(:call).with(
        hash_including(:column_1),
        kind_of(Class)
      ).exactly(ActiveRecordReEncryptStatementSpec.count).times
    end
  end
end
