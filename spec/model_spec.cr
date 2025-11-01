require "./spec_helper"

describe Crecto::Model do
  context "json: " do
    it "can be instatiated from json" do
      user = User.from_json(%|{"name":"test"}|)
      user.name.should eq("test")
    end

    it "sets default values" do
      model = DefaultValue.from_json(%|{"default_string":"overridden"}|)
      model.default_string.should eq("overridden")
      model.default_int.should eq(64)
    end
  end

  context "mass assignment: " do
    describe "compile-time type checks" do
      it "can be created from a double splat" do
        user = User.cast!(name: "test")
        user.name.should eq("test")
      end

      it "can be updated from a double tuple" do
        user = User.new
        user.cast!(name: "new name")
        user.name.should eq("new name")
      end

      it "can be created from a named tuple" do
        user = User.cast!({name: "test"})
        user.name.should eq("test")
      end

      it "can be updated from a named tuple" do
        user = User.new
        user.cast!({name: "new name"})
        user.name.should eq("new name")
      end
    end

    describe "runtime assignments" do
      it "can be created from a double splat" do
        user = User.cast(name: "test")
        user.name.should eq("test")
      end

      it "can be created from a named tuple" do
        user = User.cast({name: "test"})
        user.name.should eq("test")
      end

      it "can be created from a named tuple and a whitelist of allowed attributes" do
        user = User.cast({name: "test", things: 3}, {:name})
        user.name.should eq("test")
        user.things.should eq(nil)
      end

      it "ignores unknown attributes" do
        user = User.cast({name: "test", some_nonexisting_thing: 3})
        user.cast({some_other_nonexisting_thing: 3}, {:some_other_nonexisting_thing})
        user.name.should eq("test")
      end

      it "supports hashes with symbol keys" do
        user = User.cast({:name => "test"})
        user.name.should eq("test")
      end

      it "supports hashes with string keys" do
        user = User.cast({"name" => "test"})
        user.name.should eq("test")
      end

      it "raises on runtime if a type doesn't match" do
        expect_raises(TypeCastError) do
          User.cast({name: 1})
        end
      end

      it "can be restricted with a whitelist" do
        user = User.cast({:name => "test", :things => 3}, [:name])
        user.name.should eq("test")
        user.things.should eq(nil)
      end

      it "allows keyword initialization" do
        user = User.new(name: "Test User")
        user.name.should eq("Test User")
      end
    end
  end
end
