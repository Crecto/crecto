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
        User.changeset_fields.should eq([:name, :things, :nope, :yep, :some_date])
      end

      it "should set properties for the fields" do
        u = User.new
        u.name = "fridge"
        u.things = 123
        u.stuff = 543
        u.nope = 3.343
        u.yep = false

        u.name.should eq("fridge")
        u.things.should eq(123)
        u.stuff.should eq(543)
        u.nope.should eq(3.343)
        u.yep.should eq(false)
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

        u.to_query_hash.should eq({:name => "tester", :things => 6644, :nope => 34.9900, :created_at => nil, :updated_at => nil})
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
  end
end
