class Organization

  def initialize(account, client)
    @account = account
    @client = client || Octokit::Client.new
  end

  attr_accessor :client

  def data
    @data ||=
      begin
        client.organization @account
      rescue Octokit::NotFound
        nil
      end
  end

  def name
    data.name
  end

  def repos
    @repos ||= client.repositories @account
  end

end
