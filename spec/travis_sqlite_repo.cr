module Repo
  extend Crecto::Repo

  config do |conf|
    conf.adapter = Crecto::Adapters::SQLite3
    conf.path = "./crecto_test.db"
  end  
end