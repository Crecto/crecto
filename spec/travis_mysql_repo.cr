module Repo
  extend Crecto::Repo

  config do |conf|
    config.adapter = Crecto::Adapters::Mysql
    config.database = "crecto_test"
    config.hostname = "localhost"
    config.username = "root"
    config.port = 3306
  end
end