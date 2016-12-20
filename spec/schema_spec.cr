require "./spec_helper"

describe Crecto do
  describe "Schema" do
    describe "#schema and #field" do
      it "should set the table name" do
        User.table_name.should eq("users")
      end

      it "should set the primary key" do
        User.primary_key_field.should eq("id")
      end

      it "should set the changeset fields" do
        User.changeset_fields.should eq([:name, :things, :nope, :yep, :some_date, :pageviews])
      end

      it "should set properties for the fields" do
        u = User.new
        u.name = "fridge"
        u.things = 123
        u.stuff = 543
        u.nope = 3.343
        u.yep = false
        u.pageviews = 123451651234

        u.name.should eq("fridge")
        u.things.should eq(123)
        u.stuff.should eq(543)
        u.nope.should eq(3.343)
        u.yep.should eq(false)
        u.pageviews.should eq(123451651234)
      end

      describe "changing default values" do
        it "should set properties for the values" do
          u = UserDifferentDefaults.new

          now = Time.now
          u.xyz = now
          u.to_query_hash.should eq({:xyz => now})
          UserDifferentDefaults.primary_key_field.should eq("user_id")
        end

        it "should set the created at field" do
          UserDifferentDefaults.created_at_field.should eq("xyz")
        end
      end
    end

    describe "#to_query_hash" do
      it "should build the correct hash from the object" do
        u = User.new
        u.name = "tester"
        u.things = 6644
        u.stuff = 2343 # virtual, shouldn't be in query hash
        u.nope = 34.9900
        u.pageviews = 1234567890

        u.to_query_hash.should eq({:name => "tester", :things => 6644, :nope => 34.9900, :created_at => nil, :updated_at => nil, :pageviews => 1234567890})
      end
    end

    describe "#pkey_value" do
      it "should return the value of the primary key" do
        user = UserDifferentDefaults.new
        user.user_id = 8858
        user.pkey_value.as(Int32).should eq(user.user_id)
      end
    end

    describe "#update_primary_key" do
      it "should update the value of the primary key" do
        user = UserDifferentDefaults.new
        user.update_primary_key(9899)
        user.user_id.should eq(9899)
      end

      it "should update the value of the primary key for bigger sizes" do
        user = UserLargeDefaults.new
        user.update_primary_key(9899)
        user.id.should eq(9899)
      end
    end

    describe "#updated_at_value" do
      it "should return the updated at value" do
        now = Time.now
        u = User.new
        u.updated_at = now
        u.updated_at_value.should eq(now)
      end
    end

    describe "#created_at_value" do
      it "should return the created at value" do
        now = Time.now
        u = UserDifferentDefaults.new
        u.xyz = now
        u.created_at_value.should eq(now)
      end
    end

    describe "#updated_at_to_now" do
      it "should set the updated at value to now" do
        u = User.new
        u.updated_at_to_now
        u.updated_at.as(Time).epoch_ms.should be_close(Time.now.epoch_ms, 100)
      end
    end

    describe "#created_at_to_now" do
      it "should set the created at value to now" do
        u = UserDifferentDefaults.new
        u.created_at_to_now
        u.xyz.as(Time).epoch_ms.should be_close(Time.now.epoch_ms, 2000)
      end
    end

    describe "#klass_for_association" do
      it "should return the correct class" do
        User.klass_for_association(:posts).should eq(Post)
        User.klass_for_association(:addresses).should eq(Address)
        UserDifferentDefaults.klass_for_association(:things).should eq(Thing)
        Address.klass_for_association(:user).should eq(User)
        Post.klass_for_association(:user).should eq(User)
      end
    end

    describe "#foreign_key_for_association" do
      it "should return the correct foreign key symbol" do
        User.foreign_key_for_association(:posts).should eq(:user_id)
        User.foreign_key_for_association(:addresses).should eq(:user_id)
        Post.foreign_key_for_association(:user).should eq(:user_id)
      end
    end

    describe "#foreign_key_value_for_association" do
      it "should return the correct foreign key value for associations" do
        user = User.new
        user.name = "tester"
        user = Crecto::Repo.insert(user).instance

        post = Post.new
        post.user_id = user.id.as(Int32)
        post = Crecto::Repo.insert(post).instance

        User.foreign_key_value_for_association(:posts, post).should eq(post.user_id)
        Post.foreign_key_value_for_association(:user, post).should eq(user.id)
      end
    end

    describe "#association_type_for_association" do
      it "should return the association type symbol" do
        User.association_type_for_association(:posts).should eq(:has_many)
        User.association_type_for_association(:addresses).should eq(:has_many)
        Post.association_type_for_association(:user).should eq(:belongs_to)
      end
    end
  end
end
