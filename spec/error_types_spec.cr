require "./spec_helper"

describe Crecto::BulkError do
  describe "#initialize" do
    it "creates error with basic information" do
      error = Crecto::BulkError.new(:insert, "users", 5, 95)
      error.operation_type.should eq(:insert)
      error.table_name.should eq("users")
      error.failed_count.should eq(5)
      error.success_count.should eq(95)
      error.message.to_s.should contain("Bulk insert operation on users failed")
      error.message.to_s.should contain("5 of 100 operations failed")
    end

    it "creates error with detailed error messages" do
      errors = ["Foreign key constraint violation", "Duplicate key error"]
      error = Crecto::BulkError.new(:update, "posts", 2, 8, errors)
      error.errors.should eq(errors)
      error.message.to_s.should contain("Bulk update operation on posts failed")
    end

    it "creates error with changeset errors" do
      changeset_errors = [
        {:name => ["can't be blank"]},
        {:email => ["invalid format"]}
      ]
      error = Crecto::BulkError.new(:insert, "users", 2, 0, [] of String, changeset_errors)
      error.changeset_errors.should eq(changeset_errors)
    end
  end
end

describe Crecto::AssociationError do
  describe "#initialize" do
    it "creates error with association information" do
      error = Crecto::AssociationError.new(:user, "Post", :set, :user_id)
      error.association_name.should eq(:user)
      error.model_class.should eq("Post")
      error.operation.should eq(:set)
      error.foreign_key.should eq(:user_id)
      error.message.to_s.should contain("Association 'user' on Post failed during set")
      error.message.to_s.should contain("foreign key: user_id")
    end

    it "creates error without foreign key" do
      error = Crecto::AssociationError.new(:comments, "Post", :load)
      error.association_name.should eq(:comments)
      error.model_class.should eq("Post")
      error.operation.should eq(:load)
      error.foreign_key.should be_nil
      error.message.to_s.should contain("Association 'comments' on Post failed during load")
      error.message.to_s.should_not contain("foreign key")
    end
  end
end

describe Crecto::IteratorError do
  describe "#initialize" do
    it "creates error with basic iterator information" do
      error = Crecto::IteratorError.new("SELECT * FROM users", 1000, 500)
      error.query.should eq("SELECT * FROM users")
      error.batch_size.should eq(1000)
      error.processed_count.should eq(500)
      error.message.to_s.should contain("Iterator operation failed")
      error.message.to_s.should contain("after processing 500 records")
      error.message.to_s.should contain("with batch size 1000")
      error.message.to_s.should contain("for query: SELECT * FROM users")
    end

    it "creates error with original exception" do
      original_error = Exception.new("Connection lost")
      error = Crecto::IteratorError.new("SELECT * FROM posts", 500, 250, original_error)
      error.original_error.should eq(original_error)
      error.message.to_s.should contain("Connection lost")
    end

    it "creates error with minimal information" do
      error = Crecto::IteratorError.new(nil, 100, 0)
      error.query.should be_nil
      error.batch_size.should eq(100)
      error.processed_count.should eq(0)
      error.message.to_s.should contain("Iterator operation failed")
      error.message.to_s.should contain("with batch size 100")
      error.message.to_s.should_not contain("after processing")
    end
  end
end