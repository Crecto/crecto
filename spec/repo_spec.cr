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

    describe "#get" do
      it "should return a user" do
        row = Crecto::Repo.get(User, 1121)
        row.as(Array)[0].should eq(1121)
      end
    end

    describe "#get_by" do
      it "should return a row" do
        row = Crecto::Repo.get_by(User, name: "fridge", id: 1121)
        row[0].should eq(1121)
      end
    end
  end 
end