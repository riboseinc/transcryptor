module Transcryptor::ActiveRecord::ReEncryptStatement
  def re_encrypt_column(table_name, attribute_name, old_opts = {}, new_opts = {}, extra_columns = [])
    Transcryptor::Instance
      .new(Transcryptor::ActiveRecord::Adapter.new(self))
      .re_encrypt(table_name, attribute_name, old_opts, new_opts, extra_columns)
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, Transcryptor::ActiveRecord::ReEncryptStatement)
