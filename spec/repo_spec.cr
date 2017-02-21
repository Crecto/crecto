require "./spec_helper"

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

        changeset = Crecto::Repo.insert(u)
        changeset.instance.id.should_not eq(nil)
        changeset.instance.created_at.should_not eq(nil)
        changeset.instance.updated_at.should_not eq(nil)
      end

      it "should use the correct primary key and created_at fields" do
        u = UserDifferentDefaults.new
        u.name = "tedd"

        changeset = Crecto::Repo.insert(u)

        changeset.instance.user_id.should_not eq(nil)
        changeset.instance.xyz.should_not eq(nil)
      end

      it "should return a changeset and set the changeset action" do
        u = UserDifferentDefaults.new
        u.name = "test"

        changeset = Crecto::Repo.insert(u)

        changeset.is_a?(Crecto::Changeset::Changeset).should eq(true)
        changeset.action.should eq(:insert)
      end

      it "should use different sized primary key" do
        u = UserLargeDefaults.new
        u.name = "whatever"

        changeset = Crecto::Repo.insert(u)
        changeset.instance.id.should_not eq(nil)
      end
    end

    describe "#all" do
      it "should return rows" do
        query = Crecto::Repo::Query
          .where(name: "fridge")
          .where("users.things < ?", [124])
          .order_by("users.name ASC")
          .order_by("users.things DESC")
          .limit(1)
        users = Crecto::Repo.all(User, query)
        users.size.should be > 0
      end

      it "should accept an array" do
        query = Crecto::Repo::Query
          .where(name: ["fridge", "steve"])

        users = Crecto::Repo.all(User, query)
        users.size.should be > 0

        query = Crecto::Repo::Query
          .where(things: [123, 999])

        users = Crecto::Repo.all(User, query)
        users.size.should be > 0
      end

      describe "#or_where" do
        it "should return the correct set" do
          user = User.new
          user.name = "or_where_user"
          user.things = 123
          Crecto::Repo.insert(user)

          query = Crecto::Repo::Query
            .or_where(name: "or_where_user", things: 999)

          users = Crecto::Repo.all(User, query)
          users.size.should be > 0

          query = Crecto::Repo::Query
            .or_where(name: "dlkjf9f9ddf", things: 123)

          users = Crecto::Repo.all(User, query)
          users.size.should be > 0
        end
      end
    end

    describe "#query" do
      it "should accept a query" do
        query = Crecto::Repo.query("select * from users")
        query.is_a?(DB::ResultSet).should be_true
        query.should_not be_nil
      end

      it "should accept a query with parameters" do
        user = User.new
        user.name = "awesome-dude"
        Crecto::Repo.insert(user)

        query = Crecto::Repo.query("select * from users where name = ?", ["awesome-dude"])
        query.should_not be_nil
        query.is_a?(DB::ResultSet).should be_true
      end

      it "should accept a query and cast result" do
        users = Crecto::Repo.query(User, "select * from users")
        users.size.should be > 0
      end

      it "should accept a query with parameters and cast result" do
        query = Crecto::Repo.query(User, "select * from users where name = ?", ["awesome-dude"])
        query.size.should eq(1)
        query[0].is_a?(User).should be_true
      end
    end

    describe "#get" do
      it "should return a user" do
        now = Time.now

        user = User.new
        user.name = "test"
        user.some_date = now
        changeset = Crecto::Repo.insert(user)
        id = changeset.instance.id
        user = Crecto::Repo.get(User, id)
        user.is_a?(User).should eq(true)
        user.id.should eq(id)
        user.some_date.as(Time).to_local.epoch_ms.should be_close(now.epoch_ms, 2000)
      end

      it "should raise NoResults error if not in db" do
        expect_raises(Crecto::NoResults) do
          user = Crecto::Repo.get(User, 99999)
        end
      end
    end

    describe "#get_by" do
      it "should return a row" do
        user = User.new
        user.name = "fridge"
        changeset = Crecto::Repo.insert(user)
        id = changeset.instance.id

        user = Crecto::Repo.get_by(User, name: "fridge", id: id).as(User)
        user.id.should eq(id)
        user.name.should eq("fridge")
      end

      it "should not return a row" do
        user = Crecto::Repo.get_by(User, id: 99999)
        user.nil?.should be_true
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
        changeset = Crecto::Repo.insert(u)
        u = changeset.instance
        u.name = "new name"
        changeset = Crecto::Repo.update(u)
        changeset.instance.name.should eq("new name")
        changeset.valid?.should eq(true)
        changeset.instance.updated_at.as(Time).to_local.epoch_ms.should be_close(Time.now.epoch_ms, 2000)
      end

      it "should return a changeset and set the changeset action" do
        u = UserDifferentDefaults.new
        u.name = "test"

        changeset = Crecto::Repo.insert(u)
        u = changeset.instance
        u.name = "changed"

        changeset = Crecto::Repo.update(u)

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
        changeset = Crecto::Repo.insert(u)
        u = changeset.instance
        changeset = Crecto::Repo.delete(u)
      end

      it "should return a changeset and set the changeset action" do
        u = UserDifferentDefaults.new
        u.name = "test"

        changeset = Crecto::Repo.insert(u)
        u = changeset.instance

        changeset = Crecto::Repo.delete(u)

        changeset.is_a?(Crecto::Changeset::Changeset).should eq(true)
        changeset.action.should eq(:delete)
      end
    end

    describe "#update_all" do
      it "should update multiple records" do
        user = User.new
        user.name = "updated_all"
        user.things = 872384732
        Crecto::Repo.insert(user).instance.id

        user = User.new
        user.name = "updated_all"
        user.things = 98347598
        Crecto::Repo.insert(user).instance.id

        user = User.new
        user.name = "not_updated_all"
        user.things = 2334234
        id3 = Crecto::Repo.insert(user).instance.id

        query = Crecto::Repo::Query
          .where(name: "updated_all")

        Crecto::Repo.update_all(User, query, {:things => 42})

        # should update first two
        users = Crecto::Repo.all(User, query)
        users.each do |user|
          user.things.should eq(42)
        end

        # should not update the last
        user = Crecto::Repo.get(User, id3)
        user.things.should eq(2334234)
      end
    end

    describe "has_one" do
      it "should load the association" do
        user = User.new
        user.name = "fridge"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        Crecto::Repo.insert(post)
        post = Crecto::Repo.insert(post).instance

        post = Crecto::Repo.get(user, :post)
        post.class.should eq(Post)
      end

      it "should preload the association" do
        user = User.new
        user.name = "fridge"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        Crecto::Repo.insert(post)
        post = Crecto::Repo.insert(post).instance

        query = Crecto::Repo::Query.where(id: user.id).preload(:post)
        users = Crecto::Repo.all(User, query)
        users[0].post.should_not be_nil
      end
    end

    describe "has_many" do
      it "should load associations" do
        user = User.new
        user.name = "fridge"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        Crecto::Repo.insert(post)
        post = Crecto::Repo.insert(post).instance

        address = Address.new
        address.user_id = user.id.as(Int32)
        Crecto::Repo.insert(address)

        posts = Crecto::Repo.all(user, :posts).as(Array(Post))
        posts.size.should eq(2)
        posts[0].user_id.should eq(user.id)

        addresses = Crecto::Repo.all(user, :addresses).as(Array(Address))
        addresses.size.should eq(1)
        addresses[0].user_id.should eq(user.id)
      end
    end

    describe "belongs_to" do
      it "should set the belongs_to property" do
        user = User.new
        user.name = "fridge"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        post = Crecto::Repo.insert(post).instance
        post.user = user

        post.user.should eq(user)
      end
    end

    describe "preload" do
      it "should preload the has_many association" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        Crecto::Repo.insert(post)
        Crecto::Repo.insert(post)

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id).preload(:posts))
        users[0].posts.not_nil!.size.should eq(2)
      end

      it "should preload the has_many through association" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        project = Project.new
        project = Crecto::Repo.insert(project).instance

        user_project = UserProject.new
        user_project.project = project
        user_project.user = user
        user_project = Crecto::Repo.insert(user_project).instance

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id).preload(:projects))
        user = users[0]
        user.user_projects.not_nil!.size.should eq 1
        user.projects.not_nil!.size.should eq 1
      end

      it "shoud not preload if there are no 'through' associated records" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id).preload(:projects))
        users[0].projects.should eq(nil)
      end

      it "should preload the belongs_to association" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        post = Crecto::Repo.insert(post).instance

        posts = Crecto::Repo.all(Post, Crecto::Repo::Query.where(id: post.id).preload(:user))
        posts[0].user.as(User).id.should eq(user.id)
      end

      it "should set the foreign key when setting the object" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user = user
        post.user_id.should eq(user.id)
      end
    end

    describe "#joins" do
      it "should enforce a join in the associaton" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id).join(:posts))
        users.empty?.should eq true

        post = Post.new
        post.user = user
        post = Crecto::Repo.insert(post).instance

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id).join(:posts))
        users.size.should eq 1
      end
    end

    describe "joins through" do
      it "should load the association accross join table" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id).join(:projects))
        users.size.should eq 0

        project = Project.new
        project = Crecto::Repo.insert(project).instance

        user_project = UserProject.new
        user_project.project = project
        user_project.user = user
        user_project = Crecto::Repo.insert(user_project).instance

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id).join(:projects))
        users.size.should eq 1
      end
    end

    # keep this at the end
    describe "#delete_all" do
      it "should remove all records" do
        Crecto::Repo.delete_all(UserProject)
        Crecto::Repo.delete_all(Project)
        Crecto::Repo.delete_all(Post)
        Crecto::Repo.delete_all(Address)
        Crecto::Repo.delete_all(User)
        Crecto::Repo.delete_all(UserDifferentDefaults)
        Crecto::Repo.delete_all(UserLargeDefaults)

        user_projects = Crecto::Repo.all(UserProject)
        user_projects.size.should eq 0

        projects = Crecto::Repo.all(Project)
        projects.size.should eq 0

        posts = Crecto::Repo.all(Post)
        posts.size.should eq 0

        addresses = Crecto::Repo.all(Address)
        addresses.size.should eq 0

        users = Crecto::Repo.all(User)
        users.size.should eq 0

        users = Crecto::Repo.all(UserDifferentDefaults)
        users.size.should eq 0

        users = Crecto::Repo.all(UserLargeDefaults)
        users.size.should eq 0
      end
    end
  end
end
