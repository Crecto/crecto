require "./spec_helper"

describe Crecto do
  describe "Changeset" do
    describe "#validate_required" do
      it "should not be valid" do
        u = UserRequired.new
        changeset = UserRequired.changeset(u)
        changeset.valid?.should eq(false)
      end

      it "should have some errors" do
        u = UserRequired.new
        changeset = UserRequired.changeset(u)
        changeset.errors.size.should be > 0
        changeset.errors[0].should eq({:field => "name", :message => "is required"})
      end
    end

    # describe "#validate_format" do
    #   it "should not be valid" do
    #     u = User.new
    #     u.name = "123"
    #     u.nope = 0.123
    #     u.things = 123
    #     changeset = User.changeset(u)
    #     changeset.valid?.should eq(false)
    #   end

    #   it "should have some errors" do
    #     u = User.new
    #     u.name = "123"
    #     u.nope = 0.123
    #     u.things = 123
    #     changeset = User.changeset(u)
    #     changeset.errors.size.should be > 0
    #     changeset.errors[0].should eq({:field => "name", :message => "is invalid"})
    #   end
    # end

    # describe "#validate_inclusion" do
    #   u = User.new
    #   u.nope = 0.123
    #   u.things = 123
    #   u.name = "fred"
    #   changeset = User.changeset(u)
    #   changeset.valid?.should eq(false)
    #   puts changeset.errors
    # end
  end
end