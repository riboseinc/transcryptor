# frozen_string_literal: true

require 'spec_helper'

ActiveRecord::Base.connection.create_table(:instance_specs) do |t|
  t.string :encrypted_column_1
  t.string :encrypted_column_1_iv
  t.string :encrypted_column_1_salt
end

class InstanceSpec < ActiveRecord::Base
end

describe Transcryptor::Instance do
  let(:adapter) { Transcryptor::ActiveRecord::Adapter.new(ActiveRecord::Base.connection) }
  subject { described_class.new(adapter) }
  after { InstanceSpec.delete_all }

  before do
    attr_encrypted_config_before
    3.times do |i|
      InstanceSpec.create!(column_1: "value_#{i}")
    end
  end

  after do
    attr_encrypted_config_after
    InstanceSpec.all.each_with_index do |instance_spec, i|
      expect(instance_spec.column_1).to eq("value_#{i}")
    end
    InstanceSpec.instance_variable_set(:@encrypted_attributes, {})
  end

  describe '#re_encrypt' do
    context 'from per_attribute_iv to per_attribute_iv_and_salt' do
      let(:attr_encrypted_config_before) do
        InstanceSpec.send(
          :attr_encrypted, :column_1,
          key: 'column_1_key_qwe_qwe_qwe_qwe_qwe', mode: :per_attribute_iv
        )
      end

      let(:attr_encrypted_config_after) do
        InstanceSpec.send(
          :attr_encrypted, :column_1,
          key: 'column_1_key_asd_asd_asd_asd_asd', mode: :per_attribute_iv_and_salt
        )
      end

      it 're-encrypts attribute' do
        subject.re_encrypt(
          'instance_specs',
          :column_1,
          { key: 'column_1_key_qwe_qwe_qwe_qwe_qwe', mode: :per_attribute_iv },
          { key: 'column_1_key_asd_asd_asd_asd_asd', mode: :per_attribute_iv_and_salt }
        )
      end
    end

    context 'using lambda expression as a key' do
      let(:attr_encrypted_config_before) do
        InstanceSpec.send(
          :attr_encrypted, :column_1,
          key: ->(_instance_spec) { 'column_1_key_qwe_qwe_qwe_qwe_qwe' }
        )
      end

      let(:attr_encrypted_config_after) do
        InstanceSpec.send(
          :attr_encrypted, :column_1,
          key: ->(_instance_spec) { 'column_1_key_asd_asd_asd_asd_asd' }
        )
      end

      it 're-encrypts attribute' do
        subject.re_encrypt(
          'instance_specs',
          :column_1,
          { key: ->(_instance_spec) { 'column_1_key_qwe_qwe_qwe_qwe_qwe' } },
          { key: ->(_instance_spec) { 'column_1_key_asd_asd_asd_asd_asd' } }
        )
      end
    end
  end
end
