require "./spec_helper"
require "./helper_methods"

describe Crecto do
  describe "Repo" do
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
        query = Query
          .where(name: ["fridge", "steve"])

        users = Repo.all(User, query)
        users.size.should be > 0

        query = Query
          .where(things: [123, 999])

        users = Repo.all(User, query)
        users.size.should be > 0
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

    describe "#update" do
      it "should update the model" do
        u = User.new
        u.name = "fridge"
        u.things = 123
        u.nope = 12.45432
        u.yep = false
        u.stuff = 9993
        u.pageviews = 123245667788
        changeset = Repo.insert(u)
        u = changeset.instance
        u.name = "new name"
        changeset = Repo.update(u)
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
          a = Address.new;a.user = u;Repo.insert(a)
        end

        Repo.all(Address, Query.where(user_id: u.id)).size.should eq 2
        Repo.delete(u)
        Repo.all(Address, Query.where(user_id: u.id)).size.should eq 0
      end

      it "should make nil nillify dependents" do
        u = quick_create_user("nil dependents")
        up1 = UserProject.new;up1.user = u;up1 = Repo.insert(up1).instance
        up2 = UserProject.new;up2.user = u;up2 = Repo.insert(up2).instance

        Repo.all(UserProject, Query.where(user_id: u.id)).size.should eq 2
        Repo.delete(u)
        Repo.all(UserProject, Query.where(user_id: u.id)).size.should eq 0
        Repo.get(UserProject, up1.id).not_nil!.user_id.should eq nil
        Repo.get(UserProject, up2.id).not_nil!.user_id.should eq nil
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

        post = Repo.get(user, :post)
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

        posts = Repo.all(user, :posts).as(Array(Post))
        posts.size.should eq(2)
        posts[0].user_id.should eq(user.id)

        addresses = Repo.all(user, :addresses).as(Array(Address))
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
        users[0].posts.not_nil!.size.should eq(2)
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
        user.user_projects.not_nil!.size.should eq 1
        user.projects.not_nil!.size.should eq 1
      end

      it "shoud not preload if there are no 'through' associated records" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        users = Repo.all(User, Query.where(id: user.id).preload(:projects))
        users[0].projects.should eq(nil)
      end

      it "should preload the belongs_to association" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id
        post = Repo.insert(post).instance

        posts = Repo.all(Post, Query.where(id: post.id).preload(:user))
        posts[0].user.as(User).id.should eq(user.id)
      end

      it "should set the foreign key when setting the object" do
        user = User.new
        user.name = "tester"
        user = Repo.insert(user).instance

        post = Post.new
        post.user = user
        post.user_id.should eq(user.id)
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
  end
end
