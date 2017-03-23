require "../spec_helper"
require "../helper_methods"

module Crecto
  module Adapters
    module SQLite3
      def self.exec_execute(query_string, params, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string
        previous_def(query_string, params, tx)
      end

      def self.exec_execute(query_string, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string
        previous_def(query_string, tx)
      end

      def self.exec_execute(query_string, params)
        Crecto::Adapters.sqls << query_string
        previous_def(query_string, params)
      end

      def self.exec_execute(query_string)
        Crecto::Adapters.sqls << query_string
        previous_def(query_string)
      end
    end
  end
end

if Crecto::Repo::ADAPTER == Crecto::Adapters::SQLite3

  describe "Crecto::Adapters::SQLite3" do
    Spec.before_each do
      Crecto::Adapters.clear_sql
    end

    it "should generate insert query" do
      u = Crecto::Repo.insert(User.from_json(%({ "name": "chuck" })))
      check_sql do |sql|
        sql.should eq([
          "INSERT INTO users (name, created_at, updated_at) VALUES (?, ?, ?)",
          "SELECT * FROM users WHERE id = #{u.instance.id}"
        ])
      end
    end

  end

end
