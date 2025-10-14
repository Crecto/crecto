require "../spec_helper"
require "../helper_methods"

# SQL capture is now handled in the SQLite3 adapter itself

if Repo.config.adapter == Crecto::Adapters::SQLite3
  describe "Crecto::Adapters::SQLite3" do
    Spec.before_each do
      Crecto::Adapters.clear_sql
    end

    it "should generate insert query" do
      check_sql do |sql|
        u = Repo.insert(User.from_json(%({ "name": "chuck", "yep": false })))
        sql.should eq([
          "INSERT INTO users (name, things, smallnum, nope, yep, some_date, pageviews, unique_field, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          "SELECT * FROM users WHERE (id = '#{u.instance.id}')",
        ])
      end
    end

    it "should generate get query" do
      user = Repo.insert(User.from_json("{ \"name\":\"lucy\" }"))
      check_sql do |sql|
        Repo.get(User, user.instance.id)
        sql.should eq(["SELECT * FROM users WHERE (id=?) LIMIT 1"])
      end
    end

    it "should generate sql for query syntax" do
      query = Query
        .where(name: "fridge")
        .where("users.things < ?", [124])
        .order_by("users.name ASC")
        .order_by("users.things DESC")
        .limit(1)
      check_sql do |sql|
        Repo.all(User, query)
        sql.should eq(["SELECT users.* FROM users WHERE ((users.name=?) AND (users.things < ?)) ORDER BY users.name ASC, users.things DESC LIMIT 1"])
      end
    end

    it "should generate update queries" do
      changeset = Repo.insert(User.from_json(%({ "name": "linus", "yep": true })))
      check_sql do |sql|
        changeset.instance.name = "snoopy"
        changeset.instance.yep = false
        Repo.update(changeset.instance)
        sql.should eq([
          "UPDATE users SET name=?, things=?, smallnum=?, nope=?, yep=?, some_date=?, pageviews=?, unique_field=?, created_at=?, updated_at=?, id=? WHERE (id=?)",
          "SELECT * FROM users WHERE (id=?)",
        ])
      end
    end

    it "should generate delete queries" do
      changeset = Repo.insert(User.from_json(%({ "name": "sally" })))
      check_sql do |sql|
        Repo.delete(changeset.instance)
        sql.should eq(
          ["DELETE FROM addresses WHERE (addresses.user_id=?)",
           "SELECT user_projects.project_id FROM user_projects WHERE (user_projects.user_id=?)",
           "SELECT * FROM users WHERE (id=?)",
           "DELETE FROM users WHERE (id=?)"])
      end
    end

    it "should generate IS NULL query" do
      quick_create_user("nullable")
      check_sql do |sql|
        query = Query.where(things: nil)
        Repo.all(User, query)
        sql.should eq(["SELECT users.* FROM users WHERE (users.things IS NULL)"])
      end
    end

    it "should generates JOIN clause from string" do
      query = Query.join "INNER JOIN users ON users.id = posts.user_id"
      check_sql do |sql|
        Repo.all(Post, query)
        sql.should eq(["SELECT posts.* FROM posts INNER JOIN users ON users.id = posts.user_id"])
      end
    end
  end
end
