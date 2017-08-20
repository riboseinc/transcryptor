# frozen_string_literal: true

require 'spec_helper'

ActiveRecord::Base.connection.create_table(:re_encrypt_statement_specs) do |t|
  t.string   :encrypted_column_1
  t.string   :encrypted_column_1_iv
end

class ReEncryptStatementSpec < ActiveRecord::Base
  attr_encrypted :column_1, key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe'
end

class ReEncryptReEncryptStatementSpecColumn1 < ActiveRecord::Migration
  def up
    re_encrypt_column(
      :re_encrypt_statement_specs,
      :column_1,
      { key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe' },
      { key: '2asd2asd2asd2asd2asd2asd2asd2asd' }
    )
  end
end

describe Transcryptor::ActiveRecord::ReEncryptStatement do
  let!(:re_encrypt_statement_spec) { ReEncryptStatementSpec.create!(column_1: 'my_value') }

  it 'appends #re_encrupt_column to ActiveRecord::Migration instance' do
    ReEncryptReEncryptStatementSpecColumn1.migrate(:up)
    ReEncryptStatementSpec.encrypted_attributes[:column_1][:key] = '2asd2asd2asd2asd2asd2asd2asd2asd'
    expect(re_encrypt_statement_spec.reload.column_1).to eq('my_value')
  end
end
