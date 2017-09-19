# frozen_string_literal: true

require 'spec_helper'
require 'dm-migrations/migration_runner'

class DataMapperReEncryptStatementSpec
  include DataMapper::Resource

  property :id,                    Serial
  property :encrypted_column_1,    String
  property :encrypted_column_1_iv, String

  attr_encrypted :column_1, key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe'
end

DataMapper.finalize
DataMapper.auto_migrate!

describe Transcryptor::DataMapper::ReEncryptStatement do
  let!(:record) { DataMapperReEncryptStatementSpec.create!(column_1: 'my_value') }

  it 'appends #re_encrypt_column to DataMapper::Migration instance' do
    perform_data_mapper_migration
    DataMapperReEncryptStatementSpec.encrypted_attributes[:column_1][:key] = '2asd2asd2asd2asd2asd2asd2asd2asd'
    expect(record.reload.column_1).to eq('my_value')
  end

  def perform_data_mapper_migration
    migration 1, :re_encrypt_data_mapper_re_encrypt_statement_specs do
      up do
        re_encrypt_column(
          :data_mapper_re_encrypt_statement_specs,
          :column_1,
          { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
          { key: '2asd2asd2asd2asd2asd2asd2asd2asd' },
        )
      end
    end
    migrate_up!
  end
end
