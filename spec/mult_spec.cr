require "./spec_helper"

describe Crecto do
  describe "Multi" do
    describe "#insert" do
      it "should add to the @inserts" do
        user = User.new
        user.name = "test"

        multi = Multi.new
        multi.insert(user)

        multi.inserts[0].should eq({sortorder: 1, instance: user})
        multi.inserts.size.should eq(1)
      end
    end

    describe "#delete" do
      it "should add to the @deletes" do
        user = User.new
        user.name = "test"
        changeset = Repo.insert(user)
        user = changeset.instance

        multi = Multi.new
        multi.delete(changeset)

        multi.deletes[0].should eq({sortorder: 1, instance: user})
        multi.deletes.size.should eq(1)
      end
    end

    describe "#delete_all" do
      it "should add to the @delete_alls" do
        multi = Multi.new
        query = Query.new
        multi.delete_all(User, query)

        multi.delete_alls[0].should eq({sortorder: 1, queryable: User, query: query})
        multi.delete_alls.size.should eq(1)
      end
    end

    describe "#update" do
      it "should add to the @updates" do
        user = User.new
        user.name = "test"
        changeset = Repo.insert(user)
        user = changeset.instance

        user.name = "chnage"

        multi = Multi.new
        multi.update(user)

        multi.updates[0].should eq({sortorder: 1, instance: user})
        multi.updates.size.should eq(1)
      end
    end

    describe "#update_all" do
      it "should add to the @update_alls" do
        multi = Multi.new
        query = Query.new
        multi.update_all(User, query, {name: "update all changed"})

        multi.update_alls[0].should eq({sortorder: 1, queryable: User, query: query, update_hash: {:name => "update all changed"}})
        multi.update_alls.size.should eq(1)
      end
    end

    describe "sortorder" do
      it "should increment with each operation" do
        user = User.new
        user.name = "test"

        multi = Multi.new
        multi.insert(user)
        multi.update(user)
        multi.delete(user)

        multi.inserts[0].should eq({sortorder: 1, instance: user})
        multi.updates[0].should eq({sortorder: 2, instance: user})
        multi.deletes[0].should eq({sortorder: 3, instance: user})
      end
    end
  end
end
