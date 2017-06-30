module Transcryptor::ActiveRecord::ReEncryptStatement
  def re_encrypt_column(table_name, attribute_name, old_opts = {}, new_opts = {})
    adapter = Transcryptor::ActiveRecord::Adapter.new(self)
    Transcryptor::Instance.new(adapter).re_encrypt(table_name, attribute_name, old_opts, new_opts)
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include(Transcryptor::ActiveRecord::ReEncryptStatement)
