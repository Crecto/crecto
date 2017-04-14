require "../spec_helper"
require "../helper_methods"

module Crecto
  module Adapters
    module SQLite3
      def exec_execute(conn : DB::Database, query_string, params, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string
        previous_def(conn, query_string, params, tx)
      end

      def exec_execute(conn : DB::Database, query_string, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string
        previous_def(conn, query_string, tx)
      end

      def exec_execute(conn : DB::Database, query_string, params)
        Crecto::Adapters.sqls << query_string
        previous_def(conn, query_string, params)
      end

      def self.exec_execute(conn, query_string, params : Array)
        Crecto::Adapters.sqls << query_string
        previous_def(conn, query_string, params)
      end

      def exec_execute(conn : DB::Database, query_string)
        Crecto::Adapters.sqls << query_string
        previous_def(conn, query_string)
      end
    end
  end
end

if Repo.config.adapter == Crecto::Adapters::SQLite3

  describe "Crecto::Adapters::SQLite3" do
    Spec.before_each do
      Crecto::Adapters.clear_sql
    end

    it "should generate insert query" do
      u = Repo.insert(User.from_json(%({ "name": "chuck", "yep": false })))
      check_sql do |sql|
        sql.should eq([
          "INSERT INTO users (name, things, smallnum, nope, yep, some_date, pageviews, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
          "SELECT * FROM users WHERE id = '#{u.instance.id}'"
        ])
      end
    end

    it "should generate get query" do
      user = Repo.insert(User.from_json("{ \"name\":\"lucy\" }"))
      Crecto::Adapters.clear_sql
      Repo.get(User, user.instance.id)
      check_sql do |sql|
        sql.should eq(["SELECT * FROM users WHERE id=? LIMIT 1"])
      end
    end

    it "should generate sql for query syntax" do
      query = Query
        .where(name: "fridge")
        .where("users.things < ?", [124])
        .order_by("users.name ASC")
        .order_by("users.things DESC")
        .limit(1)
      Repo.all(User, query)
      check_sql do |sql|
        sql.should eq(["SELECT users.* FROM users WHERE  users.name=? AND users.things < ? ORDER BY users.name ASC, users.things DESC LIMIT 1"])
      end
    end

    it "should generate update queries" do
      changeset = Repo.insert(User.from_json(%({ "name": "linus", "yep": true })))
      Crecto::Adapters.clear_sql
      changeset.instance.name = "snoopy"
      changeset.instance.yep = false
      Repo.update(changeset.instance)
      check_sql do |sql|
        sql.should eq([
          "UPDATE users SET name=?, things=?, smallnum=?, nope=?, yep=?, some_date=?, pageviews=?, created_at=?, updated_at=?, id=? WHERE id=#{changeset.instance.id}",
          "SELECT * FROM users WHERE id = #{changeset.instance.id}"
        ])
      end
    end

    it "should generate delete queries" do
      changeset = Repo.insert(User.from_json(%({ "name": "sally" })))
      Crecto::Adapters.clear_sql
      Repo.delete(changeset.instance)
      check_sql do |sql|
        sql.should eq(
          ["DELETE FROM addresses WHERE  addresses.user_id=?",
            "SELECT user_projects.id, user_projects.project_id FROM user_projects WHERE  user_projects.user_id=?",
            "SELECT * FROM users WHERE id=#{changeset.instance.id}"])
      end
    end

    it "should generate IS NULL query" do
      quick_create_user("nullable")
      Crecto::Adapters.clear_sql
      query = Query.where(things: nil)
      Repo.all(User, query)
      check_sql do |sql|
        sql.should eq(["SELECT users.* FROM users WHERE  users.things IS NULL"])
      end
    end

  end

end