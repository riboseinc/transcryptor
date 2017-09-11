module Transcryptor::DataMapper::ReEncryptStatement
  def re_encrypt_column(table_name, attribute_name, old_opts = {}, new_opts = {}, transcryptor_opts = {})
    Transcryptor::Instance
      .new(Transcryptor::DataMapper::Adapter.new(self.adapter))
      .re_encrypt(table_name, attribute_name, old_opts, new_opts, transcryptor_opts)
  end
end

DataMapper::Migration.send(:include, Transcryptor::DataMapper::ReEncryptStatement)
