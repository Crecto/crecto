require "./spec_helper"

describe Crecto do
  describe "Repo" do
    describe "#transaction" do
      it "with an invalid changeset, should have errors" do
        user = User.new

        multi = Crecto::Multi.new
        multi.insert(user)

        multi = Crecto::Repo.transaction(multi)
        multi.errors.not_nil![0][:field].should eq("name")
        multi.errors.not_nil![0][:message].should eq("is required")
      end

      it "with a valid insert, should insert the record" do
        user = User.new
        user.name = "this should insert in the transaction"

        multi = Crecto::Multi.new
        multi.insert(user)

        multi = Crecto::Repo.transaction(multi)

        users = Crecto::Repo.all(User, Crecto::Repo::Query.order_by("id desc"))
        users[0].name.should eq("this should insert in the transaction")
      end

      it "with a valid delete, should delete the record" do
        user = User.new
        user.name = "this should delete"
        user = Crecto::Repo.insert(user).instance

        multi = Crecto::Multi.new
        multi.delete(user)
        Crecto::Repo.transaction(multi)

        users = Crecto::Repo.all(User, Crecto::Repo::Query.where(id: user.id))
        users.any?.should eq(false)
      end

      it "with a valid delete_all, should delete all records" do
        2.times do
          user = User.new
          user.name = "test"
          Crecto::Repo.insert(user)
        end

        Crecto::Repo.delete_all(Post)

        multi = Crecto::Multi.new
        # `delete_all` needs to use `exec` on tranasaction, not `query`
        multi.delete_all(User)
        Crecto::Repo.transaction(multi)

        users = Crecto::Repo.all(User)
        users.size.should eq(0)
      end

      it "with a valid update, should update the record" do
        user = User.new
        user.name = "this will change 89ffsf"
        user = Crecto::Repo.insert(user).instance

        user.name = "this should have changed 89ffsf"

        multi = Crecto::Multi.new
        multi.update(user)
        Crecto::Repo.transaction(multi)

        user = Crecto::Repo.get(User, user.id)
        user.name.should eq("this should have changed 89ffsf")
      end

      it "with a valid update_all, should update all records" do
      end
    end
  end
end
