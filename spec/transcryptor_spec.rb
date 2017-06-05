require "spec_helper"

describe Transcryptor do

  it "has a version number" do
    expect(Transcryptor::VERSION).not_to be nil
  end

  # it "does something useful" do
  #   expect(false).to eq(true)
  # end

  shared_context 'with instance' do
    let(:migration_instance) {
      double('migration_instance')
    }

    let(:instance) {
      described_class.init(migration_instance)
    }
  end

  describe '.init' do
    include_context 'with instance'

    it 'has pointer to .migration_instance' do
      expect(instance.migration_instance).to eq migration_instance
    end

    it 'has pointer to .migration_instance and they really do the same things' do
      require 'securerandom'
      nonce = SecureRandom.hex
      allow(migration_instance).to receive(:stuff).and_return(nonce)
      expect(instance.migration_instance.stuff).to eq nonce
    end

    it 'enables #execute' do
      expect(migration_instance).to receive(:execute).with(:stuff)
      instance.execute(:stuff)
    end
  end

  describe '#sanitize' do
    include_context 'with instance'

    it 'calls ActiveRecord::Base.sanitize with the same arguments' do
      require 'securerandom'
      10.times do
        random_arg = SecureRandom.hex
        expect(ActiveRecord::Base).to receive(:sanitize).with(random_arg) {|args|
          "'#{args}'"
        }
        instance.sanitize(random_arg)
      end
    end
  end

  shared_context 'with instance and no connection pool' do
    include_context 'with instance'

    before do
      allow(ActiveRecord::Base).to receive(:sanitize) {|args|
        "'#{args}'"
      }
      # allow(instance).to receive(:sanitize) do |arg|
      #   expect(ActiveRecord::Base).to receive(:sanitize).with(arg).and_wrap_original {|m, *args|
      #     "'#{args}'"
      #   }
      #
      # end
    end

  end

  describe '#get_column_names_from' do

    before do
      # RSpec::Mocks.space.proxy_for(migration_instance).reset
      allow(migration_instance).to receive(:execute)
    end

    include_context 'with instance and no connection pool'

    let(:column_expectations) { [
      {
        expected_columns: Set.new(%i[
          id
          encoded_column1
          encoded_column1_iv
          encoded_column1_salt
          encryption_key_1
          xXx_en_ing_column2_crypted_xXx
          xXx_en_ing_column2_crypted_xXx_iv
          xXx_en_ing_column2_crypted_xXx_salt
          encryption_key_2
        ]),
        table_spec: {
          table1:  {
            id_column: :id,
            columns: {
              column1: {
                prefix: 'encoded_',
                key: :encryption_key_1,
              },
              column2: {
                prefix: 'xXx_en_ing_',
                key: :encryption_key_2,
                suffix: '_crypted_xXx',
              },
            },
          },
        },
      },
      {
        expected_columns: Set.new(%i[
          id
          encoded_column3
          encoded_column3_iv
          encoded_column3_salt
          encryption_key_3
          xXx_en_ing_column4_crypted_xXx
          xXx_en_ing_column4_crypted_xXx_iv
          xXx_en_ing_column4_crypted_xXx_salt
          encryption_key_4
        ]),
        table_spec: {
          table2:  {
            id_column: :id,
            columns: {
              column3: {
                prefix: 'encoded_',
                key: :encryption_key_3,
              },
              column4: {
                prefix: 'xXx_en_ing_',
                key: :encryption_key_4,
                suffix: '_crypted_xXx',
              },
            }
          },
        },
      }
    ] }

    context 'with no iv and no salt' do
      before do
        allow(instance).to receive(:column_exists?) {|table_name, column_name|
          column_name !~ /salt|iv/
        }
      end

      it 'gives the correct column names' do
        column_expectations.each do |h|
          _table_spec = h[:table_spec]
          table_name = _table_spec.keys.first
          table_spec = _table_spec.values.first

          names = instance.get_column_names_from(table_name, table_spec)
          expect(Set.new(names)).to eq (h[:expected_columns].reject do |e|
            e =~ /iv|salt/
          end.to_set)
        end
      end
    end

    context 'with no salt' do
      before do
        allow(instance).to receive(:column_exists?) {|table_name, column_name|
          column_name !~ /salt/
        }
      end

      it 'gives the correct column names' do
        column_expectations.each do |h|
          _table_spec = h[:table_spec]
          table_name = _table_spec.keys.first
          table_spec = _table_spec.values.first

          names = instance.get_column_names_from(table_name, table_spec)
          expect(Set.new(names)).to eq (h[:expected_columns].reject do |e|
            e =~ /salt/
          end.to_set)
        end
      end
    end

  end

  describe '#updown_migrate' do
    include_context 'with instance and no connection pool'

    let(:table_column_spec) { {
      table1:  {
        id_column: :id,
        columns: {
          column1: {
            prefix: 'encoded_',
            key: :encryption_key_1,
          },
          column2: {
            prefix: 'xXx_en_ing_',
            key: :encryption_key_2,
            suffix: '_crypted_xXx',
          },
        }
      },
      table2:  {
        id_column: :id,
        columns: {
          column3: {
            prefix: 'encoded_',
            key: :encryption_key_3,
          },
          column4: {
            prefix: 'xXx_en_ing_',
            key: :encryption_key_4,
            suffix: '_crypted_xXx',
          },
        }
      },
    } }

    let(:old_spec) { {
      value:         'hello',
      attr_name:     'column1',
      insecure_mode: true,
      key:           'encryption key hi bye',
      algorithm:     'aes-256-cbc',
    } }

    let(:new_spec) { {
      key:           'new encryption key',
      insecure_mode: true,
      algorithm:     'aes-256-gcm',
    } }

    before do

      allow(migration_instance).to receive(:execute).with(
        "SELECT #{[
          :id,
          :encoded_column1,
          :encryption_key_1,
          :xXx_en_ing_column2_crypted_xXx,
          :encryption_key_2
        ].join(', ')} FROM `table1`"
      ) {
        [[1,2,3,4,5,6,7]]
      }

      allow(migration_instance).to receive(:execute).with(
        "SELECT #{[
          :id,
          :encoded_column1,
          :encryption_key_1,
          :xXx_en_ing_column2_crypted_xXx,
          :encryption_key_2
        ].join(', ')} FROM `table2`"
      ) {
        [[1,2,3,4,5,6,7]]
      }

      allow(migration_instance).to receive(:execute) {
        [[1,2,3,4,5,6,7,8,9]]
      }

      allow(Encryptor).to receive(:decrypt) { 'test ciphertext' }

    end

    it 'calls #get_column_names_from' do

      expect(instance).to receive(:get_column_names_from).with(
        :table1, table_column_spec[:table1]
      ).and_call_original

      expect(instance).to receive(:get_column_names_from).with(
        :table2, table_column_spec[:table2]
      ).and_call_original

      instance.updown_migrate(table_column_spec, old_spec, new_spec, -> o { o }, -> o { o })
    end

  end

  shared_context 're_encrypt params' do
    let(:table_name) { 'test_table' }
    let(:record_id) { "\xef\xbe\xad\xde" }

    let(:decrypt_opts_fn) {
      -> hash { hash }
    }

    let(:encrypt_opts_fn) {
      -> hash { hash }
    }

    let(:attrs_specs) { [
      {
        old: old_spec,
        new: new_spec,
      },
      {
        old: old_spec,
        new: new_spec,
      },
    ] }

    let(:short_encryption_key) {
      'encryption key hi bye'
    }

    let(:short_encryption_key_2) {
      'new encryption key'
    }

    let(:old_algo) {
      'aes-256-cbc'
    }

    let(:new_algo) {
      'aes-256-gcm'
    }

    let(:original_plaintext) {
      'richtig'
    }

    let(:ciphertext_no_iv_no_salt) {
      Encryptor.encrypt({
        value:         original_plaintext,
        insecure_mode: true,
        key:           short_encryption_key,
        algorithm:     old_algo,
      })
    }

    let(:old_spec) { {
      value:         ciphertext_no_iv_no_salt,
      attr_name:     'bob',
      insecure_mode: true,
      key:           'encryption key hi bye',
      algorithm:     'aes-256-cbc',
    } }

    let(:new_spec) { {
      key:           'new encryption key',
      insecure_mode: true,
      algorithm:     'aes-256-gcm',
    } }
  end

  describe '#re_encrypt' do
    include_context 'with instance and no connection pool'

    include_context 're_encrypt params'

    it 'executes whatever SET statement #set_clauses_for_re_encrypt() provides' do
      allow(instance).to receive(:set_clauses_for_re_encrypt).and_return(%w/hello there/)

      expected_update_statement = <<-EOF
        UPDATE `#{table_name}`
        SET hello, there
        WHERE id = '#{record_id}'
      EOF

      expect(instance).to receive(:execute).with(expected_update_statement)
      instance.re_encrypt(
        table_name,
        record_id,
        attrs_specs,
        decrypt_opts_fn,
        encrypt_opts_fn,
      )
    end

    # TBI : check that ciphertext is decryptable using new scheme?
    it 're-encrypts' do

    end

  end

  describe '#set_clauses_for_re_encrypt' do
    include_context 'with instance and no connection pool'
    include_context 're_encrypt params'

    let(:action) {
      -> {
        instance.set_clauses_for_re_encrypt(
          table_name,
          record_id,
          attrs_specs,
          decrypt_opts_fn,
          encrypt_opts_fn,
        )
      }
    }

    context 'when all columns exist' do
      before do
        allow(instance).to receive(:column_exists?) { true }
      end

      it 'calls #dec on old_spec' do
        expect(instance).to receive(:dec).
          at_least(attrs_specs.length).times.
          with(old_spec).
          and_call_original
        action[]
      end

      it 'calls #enc on new_spec' do
        expect(instance).to receive(:enc).
          at_least(attrs_specs.length).times.
          with(new_spec.merge(value: original_plaintext)).
          and_call_original
        action[]
      end

      it 'calls #decrypt_opts_fn' do
        expect(decrypt_opts_fn).to receive(:call).once.
          at_least(attrs_specs.length).times.
          and_call_original
        action[]
      end

      it 'calls #encrypt_opts_fn' do
        expect(encrypt_opts_fn).to receive(:call).once.
          at_least(attrs_specs.length).times.
          and_call_original
        action[]
      end

      it 'has UTF-8 encoding' do
        action[].flatten.each do |a|
          expect(a.encoding.to_s).to eq 'UTF-8'
        end
      end
    end

    context "if some columns don't exist" do
      let(:new_spec) { {
        key:           short_encryption_key_2,
        insecure_mode: true,
        algorithm:     new_algo,
        iv:            true,
        salt:          true,
      } }

      before do
        allow(instance).to receive(:column_exists?) { false }
      end

      it 'raises an exception' do
        expect(action).to raise_error Exception
      end
    end

  end

  describe '#column_exists?' do
    include_context 'with instance and no connection pool'

    let(:table_name)  { "hello_#{SecureRandom.hex}" }
    let(:column_name) { "there_#{SecureRandom.hex}" }

    let(:expected_query) {
      <<-EOF
            SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
            WHERE
              column_name  = '#{column_name}' AND
              table_name   = '#{table_name}' AND
              TABLE_SCHEMA = DATABASE()
      EOF
    }

    before do
      allow(migration_instance).to receive(:execute)
    end

    after do
      instance.column_exists?(table_name, column_name)
    end

    it 'calls #sanitize with expected column_name and table_name' do
      expect(instance).to receive(:sanitize).with(table_name.to_sym)
      expect(instance).to receive(:sanitize).with(column_name.to_sym)
    end

    it 'calls #execute with expected query' do
      expect(instance).to receive(:execute).with(expected_query)
    end

  end

  describe '#enc' do
    include_context 'with instance and no connection pool'

    it "throws error if parameter doesn't look like Hash" do
      #
      expect{instance.enc(:stuff)}.to raise_error TypeError
    end

    let(:result) {
      instance.enc(enc_opts)
    }

    let(:plaintext)     { 'this is a test plaintext' }
    let(:key)           { 'this is a test key' }
    let(:iv)            { 'this is a test iv' }
    let(:salt)          { 'this is a test salt' }
    let(:algorithm)     { 'aes-256-cbc' }
    let(:insecure_mode) { nil }

    let(:enc_opts) { {
      value:         plaintext,
      key:           key,
      iv:            iv,
      salt:          salt,
      algorithm:     algorithm,
      insecure_mode: insecure_mode,
    } }

    let(:block) { nil }

    context 'with no block' do
      after do
        instance.enc(enc_opts)
      end

      context 'with supplied algorithm' do
        let(:algorithm) { 'my own algorithm' }
        it 'passes such algorithm to Encryptor' do
          expect(Encryptor).to receive(:encrypt).with(
            hash_including(algorithm: 'my own algorithm')
          )
        end

      end

      context 'with no supplied algorithm' do
        let(:algorithm) { nil }
        it 'defaults to aes-256-gcm' do
          expect(Encryptor).to receive(:encrypt).with(
            hash_including(algorithm: 'aes-256-gcm')
          )
        end

      end

      context 'with a specific iv' do
        it 'uses the given iv' do
          expect(Encryptor).to receive(:encrypt).with(
            hash_including(iv: iv)
          )
        end
      end

      context 'with iv:true' do
        let(:iv) { true }
        let(:predetermined_random_iv) { SecureRandom.hex(22) }
        # 22 for key length..

        before do
          algo_cipher = double('cipher')

          allow(algo_cipher).to receive(:random_iv) {
            predetermined_random_iv
          }

          allow(OpenSSL::Cipher).to receive(:new).with(algorithm) { algo_cipher }

        end

        it 'generates iv for you' do
          expect(Encryptor).to receive(:encrypt).with(
            hash_including(iv: predetermined_random_iv)
          )
        end
      end

      context 'with a specific salt' do
        it 'uses the given salt' do
          expect(Encryptor).to receive(:encrypt).with(
            hash_including(salt: salt)
          )
        end
      end

      context 'with salt:true' do
        let(:salt) { true }

        let(:pre_determined_random_salt) {
          rand.to_s
        }

        before do
          allow(SecureRandom).to receive(:random_bytes) {
            pre_determined_random_salt
          }
        end

        it 'generates salt for you' do
          expect(Encryptor).to receive(:encrypt).with(
            hash_including(salt: pre_determined_random_salt)
          )
        end
      end

      context 'with iv=""' do
        let(:iv) { "" }

        it 'does not pass iv' do
          expect(Encryptor).to_not receive(:encrypt).with(
            hash_including(:iv)
          )
        end

      end

      context 'with nil iv' do
        let(:iv) { nil }

        it 'does not pass iv' do
          expect(Encryptor).to_not receive(:encrypt).with(
            hash_including(:iv)
          )
        end

      end


      context 'with salt=""' do
        let(:salt) { "" }

        it 'does not pass salt' do
          expect(Encryptor).to_not receive(:encrypt).with(
            hash_including(:salt)
          )
        end

      end

      context 'with nil salt' do
        let(:salt) { nil }

        it 'does not pass salt' do
          expect(Encryptor).to_not receive(:encrypt).with(
            hash_including(:salt)
          )
        end

      end


      context 'with explicit insecure_mode:false' do
        let(:insecure_mode) { false }

        context 'with iv' do
          let(:iv) { 'some random iv' }

          it 'sets insecure_mode: false' do
            expect(Encryptor).to receive(:encrypt).with(
              hash_including(insecure_mode: false)
            )
          end

        end

        context 'with nil iv' do
          let(:iv) { nil }
          it 'sets insecure_mode: true' do
            expect(Encryptor).to receive(:encrypt).with(
              hash_including(insecure_mode: true)
            )
          end

        end

        context 'with iv=""' do
          let(:iv) { '' }
          it 'sets insecure_mode: true' do
            expect(Encryptor).to receive(:encrypt).with(
              hash_including(insecure_mode: true)
            )
          end
        end
      end


      context 'with explicit insecure_mode: true' do
        let(:insecure_mode) { true }

        shared_examples_for 'all insecure_mode: true' do
          it 'sets insecure_mode: true' do
            expect(Encryptor).to receive(:encrypt).with(
              hash_including(insecure_mode: true)
            )
          end
        end

        context 'with iv' do
          let(:iv) { 'some random iv' }
          it_behaves_like 'all insecure_mode: true'
        end

        context 'with nil iv' do
          let(:iv) { nil }
          it_behaves_like 'all insecure_mode: true'
        end

        context 'with iv=""' do
          let(:iv) { '' }
          it_behaves_like 'all insecure_mode: true'
        end

      end

    end

    context 'given a block' do

      let(:yield_results) {
        {
          some: "random result #{rand}",
          key:  "new random key #{rand}",
        }
      }

      let(:opts_fn) { -> opts {
        opts.merge(yield_results)
      } }

      after do
        instance.enc(enc_opts) do |opts|
          opts_fn.(opts)
        end
      end

      it 'uses the yielded results to pass to Encryptor.encrypt' do
        expect(Encryptor).to receive(:encrypt).with(
          hash_including(yield_results)
        )
      end
    end


    context 'base64 inputs & outputs' do
      let(:iv)            { SecureRandom.random_bytes }
      let(:expected_iv)   { iv }
      let(:salt)          { SecureRandom.random_bytes }
      let(:expected_salt) { salt }
      let(:key)           { SecureRandom.hex }

      let(:expected_ciphertext) { 'test ciphertext' }

      before do
        allow(Encryptor).to receive(:encrypt) { expected_ciphertext }
      end

      let(:result)        { instance.enc(enc_opts.merge(
        insecure_mode:  true,
        decode64_salt:  decode64_salt,
        encode64_salt:  encode64_salt,
        decode64_iv:    decode64_iv,
        encode64_iv:    encode64_iv,
        decode64_value: decode64_value,
        encode64_value: encode64_value,
      )) }

      # Set default values to 'false'
      let(:decode64_salt)  { false }
      let(:decode64_iv)    { false }
      let(:decode64_value) { false }

      # Set default values to 'false'
      let(:encode64_salt)  { false }
      let(:encode64_iv)    { false }
      let(:encode64_value) { false }

      context 'with encode64_iv:false' do
        it 'does nothing to the output iv' do
          expect(result[:iv]).to eq expected_iv
        end
      end

      context 'with encode64_iv:true' do
        let(:encode64_iv) { true }
        it 'base64-encodes the output iv' do
          expect(result[:iv]).not_to eq expected_iv
          expect(result[:iv]).to eq Base64.encode64 expected_iv
        end
      end


      context 'with encode64_salt:false' do
        it 'does nothing to the output salt' do
          expect(result[:salt]).to eq expected_salt
        end
      end

      context 'with encode64_salt:true' do
        let(:encode64_salt) { true }
        it 'base64-encodes the output salt' do
          expect(result[:salt]).not_to eq expected_salt
          expect(result[:salt]).to eq Base64.encode64 expected_salt
        end
      end



      context 'with encode64_value:false' do
        let(:encode64_value) { false }
        it 'does nothing to the output value' do
          expect(result[:value]).to eq expected_ciphertext
        end
      end

      context 'with encode64_value:true' do
        let(:encode64_value) { true }
        it 'base64-encodes the output value' do
          expect(result[:value]).not_to eq expected_ciphertext
          expect(result[:value]).to eq Base64.encode64 expected_ciphertext
        end
      end



      context 'with decode64_value:false' do
        it 'does nothing to value before passing to .encrypt'
      end

      context 'with decode64_value:true' do
        it 'base64-decodes value before passing to .encrypt'
      end


      context 'with decode64_salt:false' do
        it 'does nothing to salt before passing to .encrypt'
      end

      context 'with decode64_salt:true' do
        it 'base64-decodes salt before passing to .encrypt'
      end


      context 'with decode64_iv:false' do
        it 'does nothing to iv before passing to .encrypt'
      end

      context 'with decode64_iv:true' do
        it 'base64-decodes iv before passing to .encrypt'
      end

    end

    it 'passes value_present:false to Encryptor.encrypt'

    it 'calls Encryptor.encrypt with the correct params' do

    end

    # %i[
    #   value
    #   iv
    #   salt
    # ].each do |attr|
    #   it "returns the correct #{attr}" do
    #     expect(result[attr]).to eq expected[attr]
    #   end
    # end

  end

  describe '#dec' do
    include_context 'with instance'

    it "throws error if parameter doesn't look like Hash" do
      #
      expect{instance.dec(:stuff)}.to raise_error TypeError
    end

    context 'with iv=""' do
      let(:iv) { "" }

      it 'sets insecure_mode: true' do
        expect(Encryptor).to receive(:decrypt).with(hash_including(
          insecure_mode: true
        ))
      end

      it 'does not pass iv' do
        expect(Encryptor).to_not receive(:decrypt).with(hash_including(
          :iv
        ))
      end

    end

    context 'with nil iv' do
      let(:iv) { nil }

      it 'sets insecure_mode: true' do
        expect(Encryptor).to receive(:decrypt).with(hash_including(
          insecure_mode: true
        ))
      end

      it 'does not pass iv' do
        expect(Encryptor).to_not receive(:decrypt).with(hash_including(
          :iv
        ))
      end

    end

  end

end
