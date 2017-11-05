require "secure_random"
require "./spec_helper"
require "./helper_methods"

describe Crecto do
  describe "Repo" do
    describe "#raw_scalar" do
      it "should perform a scalar query directly on the connection" do
        Repo.delete_all(Post)
        Repo.delete_all(User)
        quick_create_user("one")
        quick_create_user("two")
        Repo.raw_scalar("select count(id) from users").should eq(2)
      end
    end

    describe "#raw_exec" do
      it "should run the exec query directly on the connection" do
        name = SecureRandom.hex(8)
        x = Repo.config.adapter == Crecto::Adapters::Postgres ? "$1" : "?"
        Repo.raw_exec("INSERT INTO users (name) VALUES (#{x})", name)
        user = Repo.get_by!(User, name: name)
        user.should_not be_nil
      end
    end

    describe "#raw_query" do
      it "should return the result set" do
        Repo.delete_all(Post)
        Repo.delete_all(User)
        names = ["one", "two"]
        quick_create_user(names[0])
        quick_create_user(names[1])

        Repo.raw_query("SELECT id, name FROM users") do |rs|
          i = 0
          rs.each do
            rs.read(Int32).should be_a(Int32)
            rs.read(String).should eq(names[i])
            i += 1
          end
        end
      end
    end

    describe "#insert" do
      it "should insert the user" do
        u = User.new
        u.name = "fridge"
        u.things = 123
        u.nope = 12.45432
        u.yep = false
        u.stuff = 9993
        u.pageviews = 10000
        u.some_date = Time.now.at_beginning_of_hour

        changeset = Repo.insert(u)
        changeset.instance.id.should_not eq(nil)
        changeset.instance.created_at.should_not eq(nil)
        changeset.instance.updated_at.should_not eq(nil)
      end

      it "should use the correct primary key and created_at fields" do
        u = UserDifferentDefaults.new
        u.name = "tedd"

        changeset = Repo.insert(u)

        changeset.instance.user_id.should_not eq(nil)
        changeset.instance.xyz.should_not eq(nil)
      end

      it "should return a changeset and set the changeset action" do
        u = UserDifferentDefaults.new
        u.name = "test"

        changeset = Repo.insert(u)

        changeset.is_a?(Crecto::Changeset::Changeset).should eq(true)
        changeset.action.should eq(:insert)
      end

      it "should use different sized primary key" do
        u = UserLargeDefaults.new
        u.name = "whatever"

        changeset = Repo.insert(u)
        changeset.instance.id.should_not eq(nil)
      end
    end

    describe "#all" do
      it "should return rows" do
        query = Query
          .where(name: "fridge")
          .where("users.things < ?", [124])
          .order_by("users.name ASC")
          .order_by("users.things DESC")
          .limit(1)
        users = Repo.all(User, query)
        users.size.should be > 0
      end

      it "should accept an array" do
        quick_create_user_with_things("fridge", 123)
        quick_create_user_with_things("steve", 999)

        query = Query
          .where(name: ["fridge", "steve"])

        users = Repo.all(User, query)
        users.size.should be > 0

        query = Query
          .where(things: [123, 999, 999])

        users = Repo.all(User, query)
        users.size.should be > 0

        query = Query
          .where(:name, [] of String)

        users = Repo.all(User, query)
        users.size.should eq 0

        query = Query
          .where(name: [] of String)

        users = Repo.all(User, query)
        users.size.should eq 0
      end

      it "should allow IS NULL queries" do
        Repo.delete_all(Post)
        Repo.delete_all(User)
        quick_create_user("is null guy")
        quick_create_user_with_things("guy", 321)

        query = Query.where(things: nil)
        users = Repo.all(User, query)

        users.size.should eq 1
      end

      it "should allow LIKE queries" do
        name = "fj3fj-20ffja"
        quick_create_user("fj3fj-20ffja")

        query = Query.where("name LIKE ?", "%#{name}%")
        users = Repo.all(User, query)
        users.size.should be > 0
      end

      it "should accept a list of preloads" do
        name = "repo_all_with_preloads"
        user = quick_create_user(name)
        post = Post.new
        post.user = user
        Repo.insert(post)
        Repo.insert(post)

        users = Repo.all(User, Query.where(name: name), preload: [:posts])
        users[0].posts.not_nil!.size.should eq(2)
      end

      describe "#or_where" do
        it "should return the correct set" do
          user = User.new
          user.name = "or_where_user"
          user.things = 123
          Repo.insert(user)

          query = Query
            .or_where(name: "or_where_user", things: 999)

          users = Repo.all(User, query)
          users.size.should be > 0

          query = Query
            .or_where(name: "dlkjf9f9ddf", things: 123)

          users = Repo.all(User, query)
          users.size.should be > 0
        end
      end
    end

    describe "#query" do
      it "should accept a query" do
        query = Repo.query("select * from users")
        query.is_a?(DB::ResultSet).should be_true
        query.should_not be_nil
      end

      it "should accept a query with parameters" do
        user = User.new
        user.name = "awesome-dude"
        Repo.insert(user)

        query = Repo.query("select * from users where name = ?", ["awesome-dude"])
        query.should_not be_nil
        query.is_a?(DB::ResultSet).should be_true
      end

      it "should accept a query and cast result" do
        users = Repo.query(User, "select * from users")
        users.size.should be > 0
      end

      it "should accept a query with parameters and cast result" do
        query = Repo.query(User, "select * from users where name = ?", ["awesome-dude"])
        query.size.should eq(1)
        query[0].is_a?(User).should be_true
      end
    end

    describe "#aggregate" do
      it "should raise InvalidOption with an invalid option" do
        expect_raises Crecto::InvalidOption do
          Repo.aggregate(User, :blurb, :id)
        end
      end

      describe "without a query" do
        it "should return the correct :avg" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)

          Repo.aggregate(User, :avg, :things).as(TestFloat).to_f.should eq 10.0
        end

        it "should return the correct :count" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)

          Repo.aggregate(User, :count, :id).should eq 3
        end

        it "should return the correct :max" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)

          Repo.aggregate(User, :max, :things).should eq 11
        end

        it "should return the correct :min" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)

          Repo.aggregate(User, :min, :things).should eq 9
        end

        it "should return the correct :sum" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)

          Repo.aggregate(User, :sum, :things).should eq 30
        end
      end

      describe "with a query" do
        it "should return the correct :avg" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)
          quick_create_user_with_things("nope", 12)
          query = Query.where(name: "test")

          Repo.aggregate(User, :avg, :things, query).as(TestFloat).to_f.should eq 10.0
        end

        it "should return the correct :count" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)
          quick_create_user_with_things("nope", 12)
          query = Query.where(name: "test")

          Repo.aggregate(User, :count, :id, query).should eq 3
        end

        it "should return the correct :max" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)
          quick_create_user_with_things("nope", 12)
          query = Query.where(name: "test")

          Repo.aggregate(User, :max, :things, query).should eq 11
        end

        it "should return the correct :min" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)
          quick_create_user_with_things("nope", 12)
          query = Query.where(name: "test")

          Repo.aggregate(User, :min, :things, query).should eq 9
        end

        it "should return the correct :sum" do
          Repo.delete_all(Post)
          Repo.delete_all(User)
          quick_create_user_with_things("test", 9)
          quick_create_user_with_things("test", 10)
          quick_create_user_with_things("test", 11)
          quick_create_user_with_things("nope", 12)
          query = Query.where(name: "test")

          Repo.aggregate(User, :sum, :things, query).should eq 30
        end
      end
    end

    describe "#get" do
      it "should return a user" do
        now = Time.now

        user = User.new
        user.name = "test"
        user.some_date = now
        changeset = Repo.insert(user)
        id = changeset.instance.id
        user = Repo.get(User, id)
        user.is_a?(User).should eq(true)
        user.not_nil!.id.should eq(id)
        user.not_nil!.some_date.as(Time).to_local.epoch_ms.should be_close(now.epoch_ms, 2000)
      end

      it "should return nil if not in db" do
        user = Repo.get(User, 99999)
        user.nil?.should eq true
      end
    end

    describe "#get!" do
      it "should return a user" do
        user = quick_create_user("lkjfl3kj3lj")
        user = Repo.get!(User, user.id)
        user.name.should eq "lkjfl3kj3lj"
      end

      it "should raise NoResults error if not in db" do
        expect_raises(Crecto::NoResults) do
          user = Repo.get!(User, 99999)
        end
      end

      it "should work with a query" do
        user = quick_create_user("get_with_a_query")
        user = Repo.get!(User, user.id, Query.where(name: "get_with_a_query"))
        user.name.should eq "get_with_a_query"
      end
    end

    describe "#get_by" do
      it "should return a row" do
        user = User.new
        user.name = "fridge"
        changeset = Repo.insert(user)
        id = changeset.instance.id

        user = Repo.get_by(User, name: "fridge", id: id).as(User)
        user.id.should eq(id)
        user.name.should eq("fridge")
      end

      it "should not return a row" do
        user = Repo.get_by(User, id: 99999)
        user.nil?.should be_true
      end
    end

    describe "#get_by!" do
      it "should return a row" do
        user = User.new
        user.name = "fridge"
        changeset = Repo.insert(user)
        id = changeset.instance.id

        user = Repo.get_by!(User, name: "fridge", id: id)
        user.id.should eq(id)
        user.name.should eq("fridge")
      end

      it "should not return a row" do
        expect_raises(Crecto::NoResults) do
          user = Repo.get_by!(User, id: 99999)
        end
      end
    end

    describe "#get_association" do
      describe "with belongs_to" do
        it "should return a single result" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance
          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          user_from_post = Repo.get_association(post, :user)
          user_from_post.should be_a(User)
          user_from_post.as(User).name.should eq(user.name)
        end

        it "should return nil if no record is found" do
          post = Post.new
          post.user_id = nil
          post = Repo.insert(post).instance

          user_from_post = Repo.get_association(post, :user)
          user_from_post.should eq(nil)
        end
      end

      describe "with has_many" do
        it "should return an array" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance
          post = Post.new
          post.user = user
          Repo.insert(post)
          Repo.insert(post)

          posts_for_user = Repo.get_association(user, :posts)
          posts_for_user.should be_a(Array(Post))
          posts_for_user.as(Array(Post)).size.should eq(2)
        end

        it "should return an empty array if no records are found" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance

          posts_for_user = Repo.get_association(user, :posts)
          posts_for_user.should be_a(Array(Post))
          posts_for_user.as(Array(Post)).size.should eq(0)
        end
      end

      describe "with has_one" do
        it "should return a has_one association result" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance
          post = Post.new
          post.user = user
          Repo.insert(post)

          post_for_user = Repo.get_association(user, :post)
          post_for_user.should be_a(Post)
        end

        it "should return nil if no record is found" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance

          post_for_user = Repo.get_association(user, :post)
          post_for_user.should eq(nil)
        end
      end
    end

    describe "#get_association!" do
      describe "with belongs_to" do
        it "should return a single result" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance
          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          user_from_post = Repo.get_association!(post, :user)
          user_from_post.should be_a(User)
          user_from_post.as(User).name.should eq(user.name)
        end

        it "should raise a NoResults error if no record is found" do
          post = Post.new
          post.user_id = nil
          post = Repo.insert(post).instance

          expect_raises(Crecto::NoResults) do
            user_from_post = Repo.get_association!(post, :user)
          end
        end
      end

      describe "with has_many" do
        it "should return an array" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance
          post = Post.new
          post.user = user
          Repo.insert(post)
          Repo.insert(post)

          posts_for_user = Repo.get_association!(user, :posts)
          posts_for_user.should be_a(Array(Post))
          posts_for_user.as(Array(Post)).size.should eq(2)
        end

        it "should return an empty array if no records are found" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance

          posts_for_user = Repo.get_association!(user, :posts)
          posts_for_user.should be_a(Array(Post))
          posts_for_user.as(Array(Post)).size.should eq(0)
        end
      end

      describe "with has_one" do
        it "should return a has_one association result" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance
          post = Post.new
          post.user = user
          Repo.insert(post)

          post_for_user = Repo.get_association!(user, :post)
          post_for_user.should be_a(Post)
        end

        it "should raise a NoResults error if no record is found" do
          user = User.new
          user.name = "test"
          user = Repo.insert(user).instance

          expect_raises(Crecto::NoResults) do
            post_for_user = Repo.get_association!(user, :post)
          end
        end
      end
    end

    describe "#update" do
      it "should update the model" do
        now = Time.now.at_beginning_of_hour
        u = User.new
        u.name = "fridge"
        u.things = 123
        u.nope = 12.45432
        u.yep = false
        u.stuff = 9993
        u.pageviews = 123245667788
        u.some_date = now
        changeset = Repo.insert(u)
        u = changeset.instance
        u.some_date.as(Time).to_local.should eq(now)
        created_at = u.created_at
        u.name = "new name"
        changeset = Repo.update(u)
        u = changeset.instance
        u.some_date.as(Time).to_local.should eq(now)
        u.created_at.should eq(created_at)
        changeset.instance.name.should eq("new name")
        changeset.valid?.should eq(true)
        changeset.instance.updated_at.as(Time).to_local.epoch_ms.should be_close(Time.now.epoch_ms, 2000)
      end

      it "should return a changeset and set the changeset action" do
        u = UserDifferentDefaults.new
        u.name = "test"

        changeset = Repo.insert(u)
        u = changeset.instance
        u.name = "changed"

        changeset = Repo.update(u)

        changeset.is_a?(Crecto::Changeset::Changeset).should eq(true)
        changeset.action.should eq(:update)
      end
    end

    describe "#delete" do
      it "should delete the model" do
        u = User.new
        u.name = "fridge"
        u.things = 123
        u.nope = 12.45432
        u.yep = false
        u.stuff = 9993
        u.pageviews = 1234512341234
        changeset = Repo.insert(u)
        u = changeset.instance
        changeset = Repo.delete(u)
      end

      it "should return a changeset and set the changeset action" do
        u = UserDifferentDefaults.new
        u.name = "test"

        changeset = Repo.insert(u)
        u = changeset.instance

        changeset = Repo.delete(u)

        changeset.is_a?(Crecto::Changeset::Changeset).should eq(true)
        changeset.action.should eq(:delete)
      end

      it "should delete destroy dependents" do
        u = quick_create_user("delete dependents")
        2.times do
          a = Address.new; a.user = u; Repo.insert(a)
        end

        Repo.all(Address, Query.where(user_id: u.id)).size.should eq 2
        Repo.delete(u)
        Repo.all(Address, Query.where(user_id: u.id)).size.should eq 0
      end

      it "should make nil nullify dependents" do
        u = UserDifferentDefaults.new
        u.name = "nil dependents"
        u = Repo.insert(u).instance
        up1 = Thing.new; up1.user = u; up1 = Repo.insert(up1).instance
        up2 = Thing.new; up2.user = u; up2 = Repo.insert(up2).instance

        Repo.all(Thing, Query.where(user_different_defaults_id: u.user_id)).size.should eq 2
        Repo.delete(u)
        Repo.all(Thing, Query.where(user_different_defaults_id: u.user_id)).size.should eq 0
        Repo.get(Thing, up1.id).not_nil!.user_different_defaults_id.should eq nil
        Repo.get(Thing, up2.id).not_nil!.user_different_defaults_id.should eq nil
      end

      it "should delete join_through destroy dependents" do
        other_p = Project.new; other_p = Repo.insert(other_p).instance
        other_up = UserProject.new; other_up.user_id = 1; other_up.project_id = other_p.id; other_up = Repo.insert(other_up).instance

        user = quick_create_user("test")

        p1 = Project.new; p1 = Repo.insert(p1).instance
        p2 = Project.new; p2 = Repo.insert(p2).instance
        up1 = UserProject.new; up1.user_id = user.id; up1.project_id = p1.id; up1 = Repo.insert(up1).instance
        up2 = UserProject.new; up2.user_id = user.id; up2.project = p2; up2 = Repo.insert(up2).instance

        Repo.all(UserProject, Query.where(user_id: user.id)).size.should eq 2
        Repo.delete(user)
        Repo.get(Project, other_p.id).should_not be_nil # should not delete un-related
        Repo.all(UserProject, Query.where(user_id: user.id)).size.should eq 0
      end
    end

    describe "#update_all" do
      it "should update multiple records" do
        user = User.new
        user.name = "updated_all"
        user.things = 872384732
        Repo.insert(user).instance.id

        user = User.new
        user.name = "updated_all"
        user.things = 98347598
        Repo.insert(user).instance.id

        user = User.new
        user.name = "not_updated_all"
        user.things = 2334234
        id3 = Repo.insert(user).instance.id

        query = Query
          .where(name: "updated_all")

        Repo.update_all(User, query, {:things => 42})

        # should update first two
        users = Repo.all(User, query)
        users.each do |user|
          user.things.should eq(42)
        end

        # should not update the last
        user = Repo.get!(User, id3)
        user.things.should eq(2334234)
      end
    end

    describe "has_one" do
      it "should load the association" do
        user = User.new
        user.name = "fridge"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id # user.id is (Int32 | Int64)
        Repo.insert(post)
        post = Repo.insert(post).instance

        post = Repo.get_association(user, :post)
        post.class.should eq(Post)
      end

      it "should preload the association" do
        user = User.new
        user.name = "fridge"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id
        Repo.insert(post)
        post = Repo.insert(post).instance

        query = Query.where(id: user.id).preload(:post)
        users = Repo.all(User, query)
        users[0].post.should_not be_nil
      end
    end

    describe "has_many" do
      it "should load associations" do
        user = User.new
        user.name = "fridge"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id
        Repo.insert(post)
        post = Repo.insert(post).instance

        address = Address.new
        address.user_id = user.id
        Repo.insert(address)

        posts = Repo.get_association(user, :posts).as(Array(Post))
        posts.size.should eq(2)
        posts[0].user_id.should eq(user.id)

        addresses = Repo.get_association(user, :addresses).as(Array(Address))
        addresses.size.should eq(1)
        addresses[0].user_id.should eq(user.id)
      end
    end

    describe "belongs_to" do
      it "should set the belongs_to property" do
        user = User.new
        user.name = "fridge"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id
        post = Repo.insert(post).instance
        post.user = user

        post.user.should eq(user)
      end
    end

    describe "preload" do
      it "should preload the has_many association" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id
        Repo.insert(post)
        Repo.insert(post)

        users = Repo.all(User, Query.where(id: user.id).preload(:posts))
        users[0].posts.size.should eq(2)
      end

      it "should preload the has_many through association" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        project = Project.new
        project = Repo.insert(project).instance

        user_project = UserProject.new
        user_project.project = project
        user_project.user = user
        user_project = Repo.insert(user_project).instance

        users = Repo.all(User, Query.where(id: user.id).preload(:projects))
        user = users[0]
        user.user_projects.size.should eq 1
        user.projects.size.should eq 1
      end

      it "should preload the has_many through association with get!" do
        user = quick_create_user("through with get!")
        project = Project.new
        project = Repo.insert(project).instance
        user_project = UserProject.new
        user_project.user = user
        user_project.project = project
        user_project = Repo.insert(user_project).instance

        user = Repo.get!(User, user.id, Query.preload(:projects))
        user.projects[0].id.should eq project.id
      end

      it "should default to an empty array if there are no has_many associated records" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        users = Repo.all(User, Query.where(id: user.id).preload(:posts))
        users[0].posts.should be_a(Array(Post))
        users[0].posts.size.should eq(0)
      end

      it "should default to an empty array if there are no 'through' associated records" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        users = Repo.all(User, Query.where(id: user.id).preload(:projects))
        users[0].user_projects.should be_a(Array(UserProject))
        users[0].user_projects.size.should eq(0)
        users[0].projects.should be_a(Array(Project))
        users[0].projects.size.should eq(0)
      end

      it "should raise an error if a has_many has not been loaded" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        users = Repo.all(User, Query.where(id: user.id))

        expect_raises(Crecto::AssociationNotLoaded) do
          users[0].posts
        end
        users[0].posts?.should eq(nil)
      end

      it "should preload the belongs_to association" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id
        post = Repo.insert(post).instance

        posts = Repo.all(Post, Query.where(id: post.id).preload(:user))
        posts[0].user.id.should eq(user.id)
      end

      it "should set the foreign key when setting the object" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        post = Post.new
        post.user = user
        post.user_id.should eq(user.id)
      end

      it "should raise an error if a belongs_to has not been loaded" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id
        post = Repo.insert(post).instance

        posts = Repo.all(Post, Query.where(id: post.id))

        expect_raises(Crecto::AssociationNotLoaded) do
          posts[0].user
        end
        posts[0].user?.should eq(nil)
      end
    end

    describe "#joins" do
      it "should enforce a join in the associaton" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        users = Repo.all(User, Query.where(id: user.id).join(:posts))
        users.empty?.should eq true

        post = Post.new
        post.user = user
        post = Repo.insert(post).instance

        users = Repo.all(User, Query.where(id: user.id).join(:posts))
        users.size.should eq 1
      end
    end

    describe "#distinct" do
      it "should return a single user" do
        user = quick_create_user("bill")
        2.times { quick_create_post(user) }

        users = Repo.all(User, Query.where(id: user.id).join(:posts))
        users.size.should eq(2)

        users = Repo.all(User, Query.where(id: user.id).join(:posts).distinct("users.id"))
        users[0].name.should be nil
        users.size.should eq(1)
      end
    end

    describe "#group_by" do
      it "should return a single user" do
        user = quick_create_user("fred")
        2.times { quick_create_post(user) }

        users = Repo.all(User, Query.where(id: user.id).join(:posts))
        users.size.should eq(2)

        users = Repo.all(User, Query.where(id: user.id).join(:posts).group_by("users.id"))
        users[0].name.should eq("fred")
        users.size.should eq(1)
      end
    end

    describe "joins through" do
      it "should load the association accross join table" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        users = Repo.all(User, Query.where(id: user.id).join(:projects))
        users.size.should eq 0

        project = Project.new
        project = Repo.insert(project).instance

        user_project = UserProject.new
        user_project.project = project
        user_project.user = user
        user_project = Repo.insert(user_project).instance

        users = Repo.all(User, Query.where(id: user.id).join(:projects))
        users.size.should eq 1
      end
    end

    unless Repo.config.adapter == Crecto::Adapters::SQLite3
      describe "small int" do
        it "shoud save and return small int type" do
          user = quick_create_user_with_smallnum("test", 4_i16)
          user.smallnum.should eq 4
          user.smallnum.class.should eq Int16
        end
      end
    end

    if Repo.config.adapter == Crecto::Adapters::Postgres
      describe "json type" do
        it "store and retrieve records" do
          u = UserJson.new
          u.settings = {one: "stuff", two: 123, three: 130912039123090}

          changeset = Repo.insert(u)
          id = changeset.instance.id

          query = Query.where("settings @> '{\"one\":\"stuff\"}'")
          users = Repo.all(UserJson, query)

          users.size.should be > 0
          user = users[0]
          user.settings.not_nil!["one"].should eq("stuff")
          user.settings.not_nil!["two"].should eq(123)
          user.settings.not_nil!["three"].should eq(130912039123090)
        end

        describe "#delete_all" do
          it "should remove all records" do
            Repo.delete_all(UserJson)
            users = Repo.all(UserJson)
            users.size.should eq 0
          end
        end
      end
    end

    # keep this at the end
    describe "#delete_all" do
      it "should delete destroy dependents" do
        u1 = quick_create_user("user 1")
        2.times do
          a = Address.new; a.user = u1; Repo.insert(a)
        end
        u2 = quick_create_user("user 2")
        2.times do
          a = Address.new; a.user = u2; Repo.insert(a)
        end

        Repo.delete_all(User, Query.where(id: [u1.id, u2.id]))

        Repo.all(Address, Query.where(user_id: u1.id)).size.should eq 0
        Repo.all(Address, Query.where(user_id: u2.id)).size.should eq 0
      end

      it "should delete THROUGH destroy dependents" do
        Repo.delete_all(Post)
        other_p = Project.new; other_p = Repo.insert(other_p).instance
        other_up = UserProject.new; other_up.user_id = 999999; other_up.project_id = other_p.id; other_up = Repo.insert(other_up).instance

        u1 = quick_create_user("test1")
        p1 = Project.new; p1 = Repo.insert(p1).instance
        up1 = UserProject.new; up1.user_id = u1.id; up1.project_id = p1.id; up1 = Repo.insert(up1).instance
        p2 = Project.new; p2 = Repo.insert(p2).instance
        up2 = UserProject.new; up2.user_id = u1.id; up2.project_id = p2.id; up2 = Repo.insert(up2).instance

        u2 = quick_create_user("test2")
        p3 = Project.new; p3 = Repo.insert(p3).instance
        up3 = UserProject.new; up3.user_id = u1.id; up3.project_id = p3.id; up3 = Repo.insert(up3).instance
        p4 = Project.new; p4 = Repo.insert(p4).instance
        up4 = UserProject.new; up4.user_id = u1.id; up4.project_id = p4.id; up4 = Repo.insert(up4).instance

        Repo.all(UserProject, Query.where(user_id: [u1.id, u2.id])).size.should eq 4

        Repo.delete_all(User)

        Repo.get(Project, other_p.id).should_not be_nil # should not delete un-related

        Repo.all(UserProject, Query.where(user_id: [u1.id, u2.id])).size.should eq 0
        Repo.all(Project, Query.where(id: [p1.id, p2.id, p3.id, p4.id])).size.should eq 0
      end

      it "should make nil nullify dependents" do
        u = UserDifferentDefaults.new
        u.name = "nil dependents"
        u = Repo.insert(u).instance
        up1 = Thing.new; up1.user = u; up1 = Repo.insert(up1).instance
        up2 = Thing.new; up2.user = u; up2 = Repo.insert(up2).instance

        u2 = UserDifferentDefaults.new
        u2.name = "nil dependents"
        u2 = Repo.insert(u2).instance
        up3 = Thing.new; up3.user = u2; up3 = Repo.insert(up3).instance
        up4 = Thing.new; up4.user = u2; up4 = Repo.insert(up4).instance

        Repo.all(Thing, Query.where(user_different_defaults_id: [u.user_id, u2.user_id])).size.should eq 4
        Repo.delete_all(UserDifferentDefaults)
        Repo.all(Thing, Query.where(user_different_defaults_id: [u.user_id, u2.user_id])).size.should eq 0
        Repo.get!(Thing, up1.id).user_different_defaults_id.should eq nil
        Repo.get!(Thing, up2.id).user_different_defaults_id.should eq nil
        Repo.get!(Thing, up3.id).user_different_defaults_id.should eq nil
        Repo.get!(Thing, up4.id).user_different_defaults_id.should eq nil
      end

      it "should remove all records" do
        Repo.delete_all(UserProject)
        Repo.delete_all(Project)
        Repo.delete_all(Post)
        Repo.delete_all(Address)
        Repo.delete_all(User)
        Repo.delete_all(UserDifferentDefaults)
        Repo.delete_all(UserLargeDefaults)

        user_projects = Repo.all(UserProject)
        user_projects.size.should eq 0

        projects = Repo.all(Project)
        projects.size.should eq 0

        posts = Repo.all(Post)
        posts.size.should eq 0

        addresses = Repo.all(Address)
        addresses.size.should eq 0

        users = Repo.all(User)
        users.size.should eq 0

        users = Repo.all(UserDifferentDefaults)
        users.size.should eq 0

        users = Repo.all(UserLargeDefaults)
        users.size.should eq 0
      end
    end

    describe "user with uuid string as primary key" do
      it "should insert with the generated id" do
        id = SecureRandom.uuid
        user = UserUUID.new
        user.name = "te'st"
        user.uuid = id

        changeset = Repo.insert(user)

        changeset.errors.any?.should eq false
        changeset.instance.uuid.should eq id
      end

      it "should update a user with a generated id" do
        id = SecureRandom.uuid
        user = UserUUID.new
        user.name = "te'st"
        user.uuid = id
        user = Repo.insert(user).instance

        user.name = "fred"
        changeset = Repo.update(user)
        changeset.errors.any?.should eq false
        changeset.instance.name.should eq "fred"
      end

      it "should delete a user with a generated id" do
        id = SecureRandom.uuid
        user = UserUUID.new
        user.name = "te'st"
        user.uuid = id
        user = Repo.insert(user).instance

        changeset = Repo.delete(user)
        changeset.errors.any?.should eq false
      end
    end
  end
end
