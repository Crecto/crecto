require "./spec_helper"

describe Crecto do
  describe "Changeset" do
    describe "#unique_constraint" do
      it "should not be valid on insert" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        u = User.new
        u.name = "test uniqueness insert"
        u.unique_field = "123"
        Repo.insert(u)

        u = User.new
        u.name = "test uniqueness insert"
        u.unique_field = "123"
        changeset = Repo.insert(u)
        changeset.errors.empty?.should be_false
        if Repo.config.adapter == Crecto::Adapters::Postgres
          changeset.errors[0].should eq({:field => "unique_field", :message => "duplicate key value violates unique constraint \"users_unique_field_key\""})
        elsif Repo.config.adapter == Crecto::Adapters::Mysql
          changeset.errors[0].should eq({:field => "unique_field", :message => "Duplicate entry '123' for key 'unique_field'"})
        elsif Repo.config.adapter == Crecto::Adapters::SQLite3
          changeset.errors[0].should eq({:field => "unique_field", :message => "UNIQUE constraint failed: users.unique_field"})
        end
      end

      it "should not be valid on update" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        u = User.new
        u.name = "test uniqueness update"
        u.unique_field = "123"
        Repo.insert(u)

        u = User.new
        u.name = "test uniqueness insert"
        u.unique_field = "before"
        u = Repo.insert(u).instance

        u.unique_field = "123"
        changeset = Repo.update(u)
        changeset.errors.empty?.should be_false
        if Repo.config.adapter == Crecto::Adapters::Postgres
          changeset.errors[0].should eq({:field => "unique_field", :message => "duplicate key value violates unique constraint \"users_unique_field_key\""})
        elsif Repo.config.adapter == Crecto::Adapters::Mysql
          changeset.errors[0].should eq({:field => "unique_field", :message => "Duplicate entry '123' for key 'unique_field'"})
        elsif Repo.config.adapter == Crecto::Adapters::SQLite3
          changeset.errors[0].should eq({:field => "unique_field", :message => "UNIQUE constraint failed: users.unique_field"})
        end
      end
    end

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

    describe "#validate_format" do
      it "should not be valid" do
        u = UserFormat.new
        u.name = "123"
        changeset = UserFormat.changeset(u)
        changeset.valid?.should eq(false)
      end

      it "should have some errors" do
        u = UserFormat.new
        u.name = "123"
        changeset = UserFormat.changeset(u)
        changeset.errors.size.should be > 0
        changeset.errors[0].should eq({:field => "name", :message => "is invalid"})
      end
    end

    describe "#validate_inclusion" do
      it "should not be valid" do
        u = UserInclusion.new
        u.name = "fred"
        changeset = UserInclusion.changeset(u)
        changeset.valid?.should eq(false)
      end

      it "should have some errors" do
        u = UserInclusion.new
        u.name = "fred"
        changeset = UserInclusion.changeset(u)
        changeset.errors.size.should be > 0
        changeset.errors[0].should eq({:field => "name", :message => "is invalid"})
      end
    end

    describe "#validate_exclusion" do
      it "should not be valid" do
        u = UserExclusion.new
        u.name = "bill"
        changeset = UserExclusion.changeset(u)
        changeset.valid?.should eq(false)
      end

      it "should have some errors" do
        u = UserExclusion.new
        u.name = "bill"
        changeset = UserExclusion.changeset(u)
        changeset.errors.size.should be > 0
        changeset.errors[0].should eq({:field => "name", :message => "is invalid"})
      end
    end

    describe "#validate_length" do
      it "should not be valid" do
        u = UserLength.new
        u.name = "fridge"
        changeset = UserLength.changeset(u)
        changeset.valid?.should eq(false)
      end

      it "should have some errors" do
        u = UserLength.new
        u.name = "fridge"
        changeset = UserLength.changeset(u)
        changeset.errors.size.should be > 0
        changeset.errors[0].should eq({:field => "name", :message => "is invalid"})
      end
    end

    describe "#validate" do
      it "should not be valid" do
        u = UserGenericValidation.new
        changeset = UserGenericValidation.changeset(u)
        changeset.valid?.should be_false
      end

      it "should have some errors" do
        u = UserGenericValidation.new
        changeset = UserGenericValidation.changeset(u)
        changeset.errors.size.should be > 0
        changeset.errors[0].should eq({:field => "_base", :message => "Password must exist"})
      end

      it "should not have some errors and be valid" do
        u = UserGenericValidation.new
        u.id = 123
        u.password = "awesome"
        changeset = UserGenericValidation.changeset(u)
        changeset.errors.size.should eq(0)
        changeset.valid?.should be_true
      end
    end

    describe "#validates" do
      it "should not be valid" do
        u = UserMultipleValidations.new
        changeset = UserMultipleValidations.changeset(u)
        changeset.valid?.should be_false
      end

      it "should error required fields" do
        u = UserMultipleValidations.new
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({:field => "first_name", :message => "is required"})
        changeset.errors[1]?.should eq({:field => "last_name", :message => "is required"})
      end

      it "should error formated fields" do
        u = UserMultipleValidations.new
        u.first_name = "asdf1234"
        u.last_name = "asdf1234"
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({:field => "first_name", :message => "is invalid"})
        changeset.errors[1]?.should eq({:field => "last_name", :message => "is invalid"})
      end

      it "should error fields with bad length" do
        u = UserMultipleValidations.new

        u.first_name = "x"
        u.last_name = "Smith"
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({:field => "first_name", :message => "is invalid"})

        u.first_name = "qwertyuiop" # size is 10
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({:field => "first_name", :message => "is invalid"})
      end

      it "should error fields within exclusions" do
        u = UserMultipleValidations.new
        u.first_name = "foo"
        u.last_name = "bar"
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({:field => "first_name", :message => "is invalid"})
        changeset.errors[1]?.should eq({:field => "last_name", :message => "is invalid"})
      end

      it "should error fields outside of inclusions" do
        u = UserMultipleValidations.new
        u.first_name = "John"
        u.last_name = "Smith"

        u.rank = 1000
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({:field => "rank", :message => "is invalid"})

        u.rank = 0
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({:field => "rank", :message => "is invalid"})
      end

      it "should not have errors and be valid" do
        u = UserMultipleValidations.new
        u.first_name = "John"
        u.last_name = "Smith"
        u.rank = 10
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors.size.should eq(0)
        changeset.valid?.should be_true
      end
    end
  end
end
