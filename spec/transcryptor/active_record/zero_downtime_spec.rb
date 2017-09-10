# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'

ActiveRecord::Base.connection.create_table(:active_record_zero_downtime_specs) do |t|
  t.string   :encrypted_column_1
  t.string   :encrypted_column_1_iv
  t.string   :encrypted_new_column_1
  t.string   :encrypted_new_column_1_iv
end

class ActiveRecordZeroDowntimeSpec < ActiveRecord::Base
  include Transcryptor::ActiveRecord::ZeroDowntime

  attr_encrypted :column_1, key: '1qwe1qwe1qwe1qwe1qwe1qwe1qwe1qwe'
  attr_encrypted :new_column_1, key: '2asd2asd2asd2asd2asd2asd2asd2asd'

  transcryptor_migrate :column_1, :new_column_1
end

describe Transcryptor::ActiveRecord::ZeroDowntime do
  let(:instance) { ActiveRecordZeroDowntimeSpec.create(column_1: 'test') }

  it 'assigns encrypted data for both attributes' do
    expect(instance.new_column_1).to eq('test')
  end

  it 'changes new attribute on change of old' do
    instance.column_1 = 'another'
    expect(instance.new_column_1).to eq('another')
  end
end
