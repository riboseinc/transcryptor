module Transcryptor::ActiveRecord::ReEncryptStatement
  def re_encrypt_column(table_name, attribute_name, old_opts = {}, new_opts = {}, transcryptor_opts = {})
    Transcryptor::Instance
      .new(Transcryptor::ActiveRecord::Adapter.new(self))
      .re_encrypt(table_name, attribute_name, old_opts, new_opts, transcryptor_opts)
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, Transcryptor::ActiveRecord::ReEncryptStatement)
