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
        users = users.as(Array)
        users.as(Array).size.should be > 0
      end

      it "should accept an array" do
        query = Crecto::Repo::Query
          .where(name: ["fridge", "steve"])

        users = Crecto::Repo.all(User, query)
        users = users.as(Array)
        users.size.should be > 0

        query = Crecto::Repo::Query
          .where(things: [123, 999])

        users = Crecto::Repo.all(User, query)
        users = users.as(Array)
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
          users.as(Array).size.should be > 0

          query = Crecto::Repo::Query
            .or_where(name: "dlkjf9f9ddf", things: 123)

          users = Crecto::Repo.all(User, query)
          users.as(Array).size.should be > 0
        end
      end
    end

    describe "#get" do
      it "should return a user" do
        now = Time.now.at_beginning_of_hour

        user = User.new
        user.name = "test"
        user.some_date = now
        changeset = Crecto::Repo.insert(user)
        id = changeset.instance.id
        user = Crecto::Repo.get(User, id).as(User)
        user.is_a?(User).should eq(true)
        user.id.should eq(id)
        user.some_date.should eq(Time.now.at_beginning_of_hour)
      end

      it "should not return a user if not in db" do
        user = Crecto::Repo.get(User, 1)
        user.nil?.should be_true
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
        user = Crecto::Repo.get_by(User, id: 1)
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
        changeset.instance.updated_at.as(Time).epoch_ms.should be_close(Time.now.epoch_ms, 2000)
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
        Crecto::Repo.insert(user).instance.as(User).id

        user = User.new
        user.name = "updated_all"
        user.things = 98347598
        Crecto::Repo.insert(user).instance.as(User).id

        user = User.new
        user.name = "not_updated_all"
        user.things = 2334234
        id3 = Crecto::Repo.insert(user).instance.as(User).id

        query = Crecto::Repo::Query
          .where(name: "updated_all")

        Crecto::Repo.update_all(User, query, {:things => 42})

        # should update first two
        users = Crecto::Repo.all(User, query).as(Array)
        users.each do |user|
          user.things.should eq(42)
        end

        # should not update the last
        user = Crecto::Repo.get(User, id3).as(User)
        user.things.should eq(2334234)
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
        Crecto::Repo.insert(post)

        address = Address.new
        address.user_id = user.id.as(Int32)
        Crecto::Repo.insert(address)

        posts = Crecto::Repo.all(user, :posts).as(Array)
        posts.size.should eq(2)
        posts[0].as(Post).user_id.should eq(user.id)

        addresses = Crecto::Repo.all(user, :addresses).as(Array)
        addresses.size.should eq(1)
        addresses[0].as(Address).user_id.should eq(user.id)
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

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id), preload: [:posts]).as(Array)
        users[0].posts.as(Array).size.should eq(2)
      end

      it "should preload the belongs_to association" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        post = Crecto::Repo.insert(post).instance

        posts = Crecto::Repo.all(Post, Crecto::Repo::Query.where(id: post.id), preload: [:user]).as(Array)
        posts[0].user.as(User).id.should eq(user.id)
      end
    end

    describe "#delete_all" do
      it "should remove all records" do
        Crecto::Repo.delete_all(Post)
        Crecto::Repo.delete_all(Address)
        Crecto::Repo.delete_all(User)
        Crecto::Repo.delete_all(UserDifferentDefaults)
        Crecto::Repo.delete_all(UserLargeDefaults)

        posts = Crecto::Repo.all(Post).as(Array)
        posts.size.should eq 0

        addresses = Crecto::Repo.all(Address).as(Array)
        addresses.size.should eq 0

        users = Crecto::Repo.all(User).as(Array)
        users.size.should eq 0

        users = Crecto::Repo.all(UserDifferentDefaults).as(Array)
        users.size.should eq 0

        users = Crecto::Repo.all(UserLargeDefaults).as(Array)
        users.size.should eq 0        
      end
    end

  end 
end
