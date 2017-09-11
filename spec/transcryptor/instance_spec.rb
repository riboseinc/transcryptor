# frozen_string_literal: true

require 'spec_helper'

ActiveRecord::Base.connection.create_table(:instance_specs) do |t|
  t.integer :lucky_integer, default: 7
  t.string  :lucky_string,  default: "jackpot!"
  t.string  :encrypted_column_1
  t.string  :encrypted_column_1_iv
  t.string  :encrypted_column_1_salt
end

class InstanceSpec < ActiveRecord::Base
end

describe Transcryptor::Instance do
  let(:adapter) { Transcryptor::ActiveRecord::Adapter.new(ActiveRecord::Base.connection) }
  subject { described_class.new(adapter) }

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
    InstanceSpec.delete_all
  end

  describe '#re_encrypt' do

    let(:column_name)  { :column_1 }
    let(:table_name)   { :instance_specs }
    let(:original_key) { 'column_1_key_qwe_qwe_qwe_qwe_qwe' }

    let(:old_configs) do
      { key: ->(poro) { original_key } }
    end

    let(:attr_encrypted_config_before) do
      InstanceSpec.send(
        :attr_encrypted, column_name,
        old_configs
      )
    end

    let(:attr_encrypted_config_after) do
      InstanceSpec.send(
        :attr_encrypted, column_name,
        new_configs
      )
    end

    context 'from per_attribute_iv to per_attribute_iv_and_salt' do
      let(:new_configs) do
        { key: 'column_1_key_asd_asd_asd_asd_asd', mode: :per_attribute_iv_and_salt }
      end

      it 'populates salt column' do
        subject.re_encrypt(
          table_name,
          column_name,
          old_configs,
          new_configs,
        )
        expect(InstanceSpec.pluck(:encrypted_column_1_salt)).to_not include(nil)
      end
    end

    context 'from per_attribute_iv_and_salt to per_attribute_iv' do

      let(:old_configs) do
        { key: original_key, mode: :per_attribute_iv_and_salt }
      end

      let(:new_configs) do
        { key: 'column_1_key_asd_asd_asd_asd_asd', mode: :per_attribute_iv }
      end

      it 're-encrypts attribute' do
        subject.re_encrypt(
          table_name,
          column_name,
          old_configs,
          new_configs,
        )
        expect(InstanceSpec.pluck(:encrypted_column_1_salt)).to eq([nil, nil, nil])
      end
    end

    context 'using lambda expression as a key' do
      context 'with no references to other columns' do

        let(:old_configs) do
          { key: ->(_instance_spec) { original_key } }
        end

        let(:new_configs) do
          { key: ->(_instance_spec) { 'column_1_key_asd_asd_asd_asd_asd' } }
        end

        it 're-encrypts attribute' do
          subject.re_encrypt(
            table_name,
            column_name,
            old_configs,
            new_configs,
          )
        end
      end

      context 'with references to other columns' do

        let(:old_configs) do
          { key: ->(_instance_spec) { original_key } }
        end

        let(:new_configs) do
          {
            key: proc do |poro|
              expect(poro.lucky_integer).to_not be_nil
              "column_1_key_asd_asd_asd_asd_as#{poro.lucky_integer}"
            end
          }
        end

        let(:transcryptor_opts) do
          {
            extra_columns: %i[lucky_integer lucky_string],
          }
        end

        it 're-encrypts attribute' do
          subject.re_encrypt(
            table_name,
            column_name,
            old_configs,
            new_configs,
            transcryptor_opts
          )
        end
      end

    end
  end
end
