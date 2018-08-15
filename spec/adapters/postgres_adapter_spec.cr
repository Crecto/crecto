require "../spec_helper"
require "../helper_methods"

module Crecto
  module Adapters
    module Postgres
      def execute(conn : DB::Database, query_string, params, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string if !tx.nil?
        previous_def(conn, query_string, params, tx)
      end

      def execute(conn : DB::Database, query_string, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string if !tx.nil?
        previous_def(conn, query_string, tx)
      end

      def exec_execute(conn : DB::Database, query_string, params, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string if !tx.nil?
        previous_def(conn, query_string, params, tx)
      end

      def exec_execute(conn : DB::Database, query_string, tx : DB::Transaction?)
        Crecto::Adapters.sqls << query_string if !tx.nil?
        previous_def(conn, query_string, tx)
      end
    end
  end
end

if Repo.config.adapter == Crecto::Adapters::Postgres
  describe "Crecto::Adapters::Postgres" do
    Spec.before_each do
      Crecto::Adapters.clear_sql
    end

    it "should generate insert query" do
      Repo.insert(User.from_json(%({ "name": "chuck" })))
      check_sql do |sql|
        sql.should eq(["INSERT INTO users (name, things, smallnum, nope, yep, some_date, pageviews, unique_field, created_at, updated_at) \
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *"])
      end
    end

    it "should generate get query" do
      user = Repo.insert(User.from_json("{ \"name\":\"lucy\" }"))
      Crecto::Adapters.clear_sql
      Repo.get(User, user.instance.id)
      check_sql do |sql|
        sql.should eq(["SELECT * FROM users WHERE (id=$1) LIMIT 1"])
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
        sql.should eq(["SELECT users.* FROM users WHERE  (users.name=$1) AND (users.things < $2) ORDER BY users.name ASC, users.things DESC LIMIT 1"])
      end
    end

    it "should generate update queries" do
      changeset = Repo.insert(User.from_json(%({ "name": "linus" })))
      Crecto::Adapters.clear_sql
      changeset.instance.name = "snoopy"
      Repo.update(changeset.instance)
      check_sql do |sql|
        sql.should eq(["UPDATE users SET (name, things, smallnum, nope, yep, some_date, pageviews, unique_field, created_at, updated_at, id) = \
          ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) WHERE (id=$12) RETURNING *"])
      end
    end

    it "should generate delete queries" do
      changeset = Repo.insert(User.from_json(%({ "name": "sally" })))
      Crecto::Adapters.clear_sql
      Repo.delete(changeset.instance)
      check_sql do |sql|
        sql.should eq(
          ["DELETE FROM addresses WHERE  (addresses.user_id=$1)",
           "SELECT user_projects.project_id FROM user_projects WHERE  (user_projects.user_id=$1)",
           "DELETE FROM users WHERE (id=$1) RETURNING *"])
      end
    end

    it "should generate IS NULL query" do
      quick_create_user("nullable")
      Crecto::Adapters.clear_sql
      query = Query.where(things: nil)
      Repo.all(User, query)
      check_sql do |sql|
        sql.should eq(["SELECT users.* FROM users WHERE  (users.things IS NULL)"])
      end
    end

    it "should generate sql for query syntax with lock" do
      query = Query
        .where(name: "fridge")
        .where("users.things < ?", [124])
        .order_by("users.name ASC")
        .order_by("users.things DESC")
        .limit(1)
      Repo.config.get_connection.transaction do |tx|
        Repo.lock(tx, User, query)
      end
      check_sql do |sql|
        sql.should eq(["SELECT users.* FROM users WHERE  (users.name=$1) AND (users.things < $2) ORDER BY users.name ASC, users.things DESC LIMIT 1 FOR UPDATE"])
      end
    end
  end
end
