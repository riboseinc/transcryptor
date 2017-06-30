class Transcryptor::AbstractAdapter
  attr_reader :connection

  def initialize(connection)
    @connection = connection
  end
end
