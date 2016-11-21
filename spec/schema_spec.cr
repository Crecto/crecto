require "./spec_helper"

describe Crecto do
  describe "Schema" do
    describe "#schema and #field" do
      it "should set the table name" do
        User.table_name.should eq("users")
      end

      it "should set the primary key" do
        User.primary_key.should eq("id")
      end

      it "should set the changeset fields" do
        User.changeset_fields.should eq([:name, :things, :nope, :yep])
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
    end
  end
end
