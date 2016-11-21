require "./spec_helper"

describe Crecto do
  describe "Repo" do
    describe "#insert" do
      it "should do things" do
        u = User.new
        u.name = "fridge"
        u.things = 123
        Crecto::Repo.insert(u)
        u.id.should_not eq(nil)
      end
    end

    describe "#all" do
      it "should return rows" do
        rows = Crecto::Repo.all(User, Crecto::Repo::Query.where(name: "fridge", things: 123).order_by("users.name").limit(1))
        rows.as(Array).size.should be > 0
      end
    end
  end 
end