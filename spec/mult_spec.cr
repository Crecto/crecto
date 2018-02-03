require "./spec_helper"

describe Crecto do
  describe "Multi" do
    describe "#insert" do
      it "should add to @operations" do
        user = User.new
        user.name = "test"

        multi = Multi.new
        multi.insert(user)

        multi.operations.first.should eq(
          Crecto::Multi::Insert.new(user)
        )
        multi.operations.size.should eq(1)
      end
    end

    describe "#delete" do
      it "should add to @operations" do
        user = User.new
        user.name = "test"
        changeset = Repo.insert(user)
        user = changeset.instance

        multi = Multi.new
        multi.delete(changeset)

        multi.operations.first.should eq(
          Crecto::Multi::Delete.new(user)
        )
        multi.operations.size.should eq(1)
      end
    end

    describe "#delete_all" do
      it "should add to the @operations" do
        multi = Multi.new
        query = Query.new
        multi.delete_all(User, query)

        multi.operations.first.should eq(
          Crecto::Multi::DeleteAll.new(User, query)
        )
        multi.operations.size.should eq(1)
      end
    end

    describe "#update" do
      it "should add to @operations" do
        user = User.new
        user.name = "test"
        changeset = Repo.insert(user)
        user = changeset.instance

        user.name = "chnage"

        multi = Multi.new
        multi.update(user)

        multi.operations.first.should eq(
          Crecto::Multi::Update.new(user)
        )
        multi.operations.size.should eq(1)
      end
    end

    describe "#update_all" do
      it "should add to @operations" do
        multi = Multi.new
        query = Query.new
        multi.update_all(User, query, {name: "update all changed"})

        multi.operations.first.should eq(
          Crecto::Multi::UpdateAll.new(User, query, { :name => "update all changed" })
        )
        multi.operations.size.should eq(1)
      end
    end

    describe "sorting" do
      it "preserves inserted order" do
        user = User.new
        user.name = "test"

        multi = Multi.new
        multi.insert(user)
        multi.update(user)
        multi.delete(user)

        multi.operations.size.should eq(3)
        first, second, third = multi.operations
        first.should eq(Crecto::Multi::Insert.new(user))
        second.should eq(Crecto::Multi::Update.new(user))
        third.should eq(Crecto::Multi::Delete.new(user))
      end
    end
  end
end
