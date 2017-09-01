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

ActiveRecord::Base.connection.create_table(:active_record_re_encrypt_statement_spec2s) do |t|
  t.integer  :lucky_integer, default: 7
  t.string   :encrypted_column_1
  t.string   :encrypted_column_1_iv
end

class ActiveRecordReEncryptStatementSpec2 < ActiveRecord::Base
  attr_encrypted :column_1, key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe'
end

class ReEncryptActiveRecordReEncryptStatementSpecColumn1 < ActiveRecord::Migration
  def up
    re_encrypt_column(
      :active_record_re_encrypt_statement_specs,
      :column_1,
      { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
      { key: '2asd2asd2asd2asd2asd2asd2asd2asd' }
    )
  end
end

class ReEncryptActiveRecordReEncryptStatementSpecColumn1WithExtraColumns < ActiveRecord::Migration
  def up
    re_encrypt_column(
      :active_record_re_encrypt_statement_spec2s,
      :column_1,
      { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
      { key: ->(o) { '2asd2asd2asd2asd2asd2asd2asd2asd'.gsub(/2/, o.lucky_integer.to_s) } },
      %i[lucky_integer]
    )
  end
end

describe Transcryptor::ActiveRecord::ReEncryptStatement do

  context 'with no extra columns specified' do
    let!(:record) { ActiveRecordReEncryptStatementSpec.create!(column_1: 'my_value') }

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      ReEncryptActiveRecordReEncryptStatementSpecColumn1.migrate(:up)
      ActiveRecordReEncryptStatementSpec.encrypted_attributes[:column_1][:key] = '2asd2asd2asd2asd2asd2asd2asd2asd'
      expect(record.reload.column_1).to eq('my_value')
    end
  end

  context 'with extra columns specified' do
    let!(:record) { ActiveRecordReEncryptStatementSpec2.create!(column_1: 'my_value') }

    it 'appends #re_encrypt_column to ActiveRecord::Migration instance' do
      ReEncryptActiveRecordReEncryptStatementSpecColumn1WithExtraColumns.migrate(:up)
      ActiveRecordReEncryptStatementSpec2.encrypted_attributes[:column_1][:key] = '7asd7asd7asd7asd7asd7asd7asd7asd'
      expect(record.reload.column_1).to eq('my_value')
    end
  end

end
