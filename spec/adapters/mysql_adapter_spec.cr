require "../spec_helper"
require "../helper_methods"

module Crecto
  module Adapters
    module Mysql
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

if Crecto::Repo::ADAPTER == Crecto::Adapters::Mysql

  describe "Crecto::Adapters::Mysql" do
    Spec.before_each do
      Crecto::Adapters.clear_sql
    end

    it "should generate insert query" do
      Crecto::Repo.insert(User.from_json(%({ "name": "chuck" })))
      check_sql do |sql|
        sql.should eq([
          "INSERT INTO users (name, things, nope, yep, some_date, pageviews, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          "SELECT * FROM users WHERE id = LAST_INSERT_ID()"
        ])
      end
    end

    it "should generate get query" do
      user = Crecto::Repo.insert(User.from_json("{ \"name\":\"lucy\" }"))
      Crecto::Adapters.clear_sql
      Crecto::Repo.get(User, user.instance.id)
      check_sql do |sql|
        sql.should eq(["SELECT * FROM users WHERE id=? LIMIT 1"])
      end
    end

    it "should generate sql for query syntax" do
      query = Crecto::Repo::Query
        .where(name: "fridge")
        .where("users.things < ?", [124])
        .order_by("users.name ASC")
        .order_by("users.things DESC")
        .limit(1)
      Crecto::Repo.all(User, query)
      check_sql do |sql|
        sql.should eq(["SELECT users.* FROM users WHERE  users.name=? AND users.things < ? ORDER BY users.name ASC, users.things DESC LIMIT 1"])
      end
    end

    it "should generate update queries" do
      changeset = Crecto::Repo.insert(User.from_json(%({ "name": "linus" })))
      Crecto::Adapters.clear_sql
      changeset.instance.name = "snoopy"
      changeset.instance.yep = false
      Crecto::Repo.update(changeset.instance)
      check_sql do |sql|
        sql.should eq([
          "UPDATE users SET name=?, things=?, nope=?, yep=?, some_date=?, pageviews=?, created_at=?, updated_at=? WHERE id=#{changeset.instance.id}",
          "SELECT * FROM users WHERE id = #{changeset.instance.id}"
        ])
      end
    end

    it "should generate delete queries" do
      changeset = Crecto::Repo.insert(User.from_json(%({ "name": "sally" })))
      Crecto::Adapters.clear_sql
      Crecto::Repo.delete(changeset.instance)
      check_sql do |sql|
        sql.should eq([] of String)
      end
    end

    it "should generate IS NULL query" do
      quick_create_user("nullable")
      Crecto::Adapters.clear_sql
      query = Crecto::Repo::Query.where(things: nil)
      Crecto::Repo.all(User, query)
      check_sql do |sql|
        sql.should eq(["SELECT users.* FROM users WHERE  users.things IS NULL"])
      end
    end

  end

end
