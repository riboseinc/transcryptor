# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

ActiveRecord::Base.connection.create_table(:active_record_re_encrypt_statement_specs) do |t|
  t.integer  :lucky_integer, default: 7
  t.string   :encrypted_column_1
  t.string   :encrypted_column_1_iv
end

class ActiveRecordReEncryptStatementSpec < ActiveRecord::Base; end

describe Transcryptor::ActiveRecord::ReEncryptStatement do

  let(:migration) do
    Kernel.const_set(
      :"Migration#{SecureRandom.hex(4)}",
      Class.new(ActiveRecord::Migration),
    )
  end

  let(:table_class) { ActiveRecordReEncryptStatementSpec }
  let(:table_name) { :active_record_re_encrypt_statement_specs }
  let(:column_name) { :column_1 }

  before do
    table_class.delete_all

    table_class.send(
      :attr_encrypted,
      column_name,
      key: old_key
    )

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

    5.times do
      table_class.create!(column_1: expected_value)
    end

    migration.migrate(:up)
    table_class.encrypted_attributes[column_name][:key] = new_key
  end

  let(:expected_value) { 'my_value' }
  let(:record) { table_class.last }

  after do
    table_class.send(
      :attr_encrypted,
      column_name,
      key: new_key
    )
    migration.migrate(:down)
  end

  let(:old_key) { '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' }
  let(:old_configs) { { key: old_key } }

  context 'with no extra columns specified' do
    let(:new_key) { '2asd2asd2asd2asd2asd2asd2asd2asd' }
    let(:up_params) do
      [
        table_name,
        column_name,
        old_configs,
        { key: new_key },
      ]
    end
    let(:down_params) do
      [
        table_name,
        column_name,
        { key: new_key },
        old_configs,
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
        table_name,
        column_name,
        old_configs,
        { key: ->(o) { '2asd2asd2asd2asd2asd2asd2asd2asd'.gsub(/2/, o.lucky_integer.to_s) } },
        extra_columns: %i[lucky_integer],
      ]
    end
    let(:down_params) do
      [
        table_name,
        column_name,
        { key: ->(_o) { new_key } },
        old_configs,
        extra_columns: %i[lucky_integer],
      ]
    end

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      expect(record.reload.column_1).to eq(expected_value)
    end
  end

  context 'with extra columns and hooks specified' do

    let(:before_decrypt_probe) { spy(:before_decrypt_probe) }
    let(:after_encrypt_probe)  { spy(:after_encrypt_probe)  }
    let(:new_key) { '7asd7asd7asd7asd7asd7asd7asd7asd' }

    let(:up_params) do
      [
        table_name,
        column_name,
        old_configs,
        { key: ->(o) { '2asd2asd2asd2asd2asd2asd2asd2asd'.gsub(/2/, o.lucky_integer.to_s) } },
        extra_columns: %i[lucky_integer],
        before_decrypt: prehook,
        after_encrypt:  posthook,
      ]
    end

    let(:down_params) do
      [
        table_name,
        column_name,
        { key: ->(_o) { new_key } },
        old_configs,
        extra_columns: %i[lucky_integer],
      ]
    end

    let(:prehook) do
      -> (old_row, decryptor_class) { before_decrypt_probe.call(old_row, decryptor_class) }
    end

    let(:posthook) do
      -> (new_row, encryptor_class) { after_encrypt_probe.call(new_row, encryptor_class) }
    end

    it 'calls before_decrypt hook' do
      expect(before_decrypt_probe).to have_received(:call).with(
        hash_including("encrypted_#{column_name}", "encrypted_#{column_name}_iv"),
        kind_of(Class)
      ).exactly(ActiveRecordReEncryptStatementSpec.count).times
    end

    it 'calls after_encrypt hook' do
      expect(after_encrypt_probe).to have_received(:call).with(
        hash_including("encrypted_#{column_name}", "encrypted_#{column_name}_iv"),
        kind_of(Class)
      ).exactly(ActiveRecordReEncryptStatementSpec.count).times
    end
  end
end
