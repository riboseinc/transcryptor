# frozen_string_literal: true

require 'spec_helper'

def create_migration_specs_table
  ActiveRecord::Base.connection.create_table(:migration_specs) do |t|
    t.string :email
    t.string :encrypted_column_1
    t.string :encrypted_column_1_iv
    t.string :encrypted_column_1_salt
    t.string :column_1_version
  end
end

def populate_migration_specs_table
  ActiveRecord::Base
    .connection
    .execute(
      <<-SQL
        INSERT INTO migration_specs (email, encrypted_column_1, encrypted_column_1_iv, column_1_version)
        VALUES ('octavio_moen@dibbert.biz', 'yaLizu7BH7WvQDXPKfLfvZDCyQ3xIwYpwo3boRYOrU0', 'T9CER1xdp/v2Ob0Q', '20180401000000'),
               ('coralie@schneiderconroy.com', 'YXB5llfqaWXpFE95ph8w+LQaCMFYuRtj4hiBoJBzSRM=', 'aHQQNnzskLdVmDIf', '20180401000000'),
               ('burma@schuppe.co.uk', 'cZgMYDC165DyOZreYIUw/70OsCiRBdJa', 'lB5LZ/3Qlts=', '20180401000002');
      SQL
    )
end

def drop_migration_specs_table
  ActiveRecord::Base.connection.drop_table(:migration_specs)
end

class MigrationSpec < ActiveRecord::Base
  attr_encrypted :column_1,
                 key:       '94dd7e2c40a3d51a8dd0a9137356a18e',
                 algorithm: 'RC2-64-CBC'
end

describe Transcryptor::Migration do
  let(:encrypted_columns_for) do
    lambda do |id|
      sql = <<-SQL
        SELECT encrypted_column_1, encrypted_column_1_iv
        FROM migration_specs WHERE id = #{id}
      SQL
      ActiveRecord::Base
        .connection
        .execute(sql)
        .first
        .slice('encrypted_column_1', 'encrypted_column_1_iv')
        .values
    end
  end

  before do
    create_migration_specs_table
    populate_migration_specs_table
  end

  after { drop_migration_specs_table }

  context 'when migration is not used' do
    let(:id) { 1 }

    it 'does not migrate encrypted fields' do
      expect { MigrationSpec.find(id) }
        .not_to change { encrypted_columns_for.call(id) }
    end

    it 'fails on attempts to access non-migrated value' do
      expect { MigrationSpec.find(id).column_1 }
        .to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'does not fail on access to migrated value' do
      expect { MigrationSpec.find(3).column_1 }.not_to raise_error
    end
  end

  context 'when migration is used' do
    before do
      described_class.draw do
        define_encryption MigrationSpec,
                          field: :column_1,
                          options: {
                            key:       '67c3800d1572d9d964a6ff3bd821ed02',
                            algorithm: 'aes-256-gcm'
                          },
                          version: 20180401000000

        define_encryption MigrationSpec,
                          field: :column_1,
                          options: {
                            key:       '94dd7e2c40a3d51a8dd0a9137356a18e',
                            algorithm: 'RC2-64-CBC'
                          },
                          version: 20180401000002
      end
    end

    context 'when record has not been migrated yet' do
      let(:id) { 1 }

      it "migrates encrypted field on model's initialization" do
        expect { MigrationSpec.find(id) }
          .to change { encrypted_columns_for.call(id) }
          .from(
            ['yaLizu7BH7WvQDXPKfLfvZDCyQ3xIwYpwo3boRYOrU0', 'T9CER1xdp/v2Ob0Q']
          )
      end
    end

    context 'when record has been already migrated' do
      let(:id) { 3 }

      it 'does not change encrypted field' do
        expect { MigrationSpec.find(id) }
          .to_not change { encrypted_columns_for.call(id) }
      end
    end

    context 'when new record is created with encrypted attribute filled' do
      let(:value) { 'foobar' }

      it 'saves encrypted field with latest encryption version' do
        expect(MigrationSpec.create(column_1: value).reload.column_1)
          .to eq(value)
        expect(MigrationSpec.last.column_1_version).to eq('20180401000002')
      end
    end
  end
end
