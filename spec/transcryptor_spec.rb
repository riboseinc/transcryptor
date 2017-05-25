require "spec_helper"

describe Transcryptor do
  it "has a version number" do
    expect(Transcryptor::VERSION).not_to be nil
  end

  # it "does something useful" do
  #   expect(false).to eq(true)
  # end

  describe '.init' do
    let(:migration_instance) {
      double('migration_instance')
    }

    let(:instance) {
      described_class.init(migration_instance)
    }

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

    describe '#updown_migrate' do

    end

    describe '#re_encrypt' do

    end

    describe '#column_exists?' do

    end

    describe '#enc' do

    end

    describe '#dec' do

    end

  end
end
