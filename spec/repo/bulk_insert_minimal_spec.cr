require "../spec_helper"

describe Repo do
  describe "insert_all" do
    it "works with basic functionality" do
      user = User.new
      user.name = "Test User"
      user.things = 25

      result = Repo.insert_all(User, [user])

      puts "Result: #{result}"
      puts "Successful: #{result.successful?}"
      puts "Successful count: #{result.successful_count}"
      puts "Failed count: #{result.failed_count}"
      puts "Errors: #{result.errors}"

      result.should be_a(Crecto::BulkResult)
      result.successful?.should be_true
      result.successful_count.should eq(1)
      result.failed_count.should eq(0)
      result.inserted_ids.size.should eq(1)
    end
  end
end