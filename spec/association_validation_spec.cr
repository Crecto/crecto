require "spec"
require "./spec_helper"

# Test models for association validation
class AssociationValidationUser < Crecto::Model
  schema "users" do
    field :name, String
    field :email, String
    field :company_id, Int32?
    field :manager_id, Int32?
    field :profile_id, Int32?
  end

  belongs_to :company, AssociationValidationCompany
  belongs_to :manager, AssociationValidationUser, foreign_key: "manager_id"
  belongs_to :profile, AssociationValidationProfile
end

class AssociationValidationCompany < Crecto::Model
  schema "companies" do
    field :name, String
    field :address, String
  end

  has_many :users, AssociationValidationUser
end

class AssociationValidationProfile < Crecto::Model
  schema "profiles" do
    field :bio, String
    field :avatar_url, String
  end

  has_one :user, AssociationValidationUser
end

class AssociationValidationPost < Crecto::Model
  schema "posts" do
    field :title, String
    field :content, String
    field :author_id, Int32?
    field :category_id, Int32?
  end

  belongs_to :author, AssociationValidationUser, foreign_key: "author_id"
  belongs_to :category, AssociationValidationCategory
end

class AssociationValidationCategory < Crecto::Model
  schema "categories" do
    field :name, String
  end

  has_many :posts, AssociationValidationPost
end

describe Crecto::Changeset do
  describe "#validate_association_foreign_keys" do
    context "without validation context (convention-based validation)" do
      it "passes when all foreign keys are nil" do
        user = AssociationValidationUser.cast(name: "John Doe")
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "passes when foreign keys have valid integer values" do
        user = AssociationValidationUser.cast(
          name: "John Doe",
          company_id: 1,
          manager_id: 2,
          profile_id: 3
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "passes when foreign keys have valid integer values" do
        user = AssociationValidationUser.cast(
          name: "John Doe",
          company_id: 1,
          manager_id: 2,
          profile_id: 3
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "adds error when foreign key value is invalid string" do
        user = AssociationValidationUser.cast({
          name: "John Doe",
          company_id: "invalid"
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should contain({"company_id", "association reference not found"})
      end

      it "adds error when foreign key value is zero" do
        user = AssociationValidationUser.cast({
          name: "John Doe",
          company_id: 0
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should contain({"company_id", "association reference not found"})
      end

      it "adds error when foreign key value is negative" do
        user = AssociationValidationUser.cast({
          name: "John Doe",
          company_id: -1
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should contain({"company_id", "association reference not found"})
      end

      it "adds errors for multiple invalid foreign keys" do
        user = AssociationValidationUser.cast({
          name: "John Doe",
          company_id: "invalid",
          manager_id: -5,
          profile_id: "not_a_number"
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should contain({"company_id", "association reference not found"})
        changeset.errors.should contain({"manager_id", "association reference not found"})
        changeset.errors.should contain({"profile_id", "association reference not found"})
      end

      it "passes when some foreign keys are nil and others are valid" do
        user = AssociationValidationUser.cast(
          name: "John Doe",
          company_id: 1,
          manager_id: nil,  # Optional association
          profile_id: 3
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "handles non-id fields correctly" do
        user = AssociationValidationUser.cast(
          name: "John Doe",
          email: "john@example.com",  # Not ending with _id, should be ignored
          company_id: 1
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "chains with other validations" do
        user = AssociationValidationUser.cast({
          company_id: "invalid"  # No name provided, so that validation will also fail
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_required(:name)
          .validate_association_foreign_keys

        changeset.errors.should contain({"name", "is required"})
        changeset.errors.should contain({"company_id", "association reference not found"})
      end
    end

    context "with custom foreign key patterns" do
      it "handles non-standard foreign key patterns" do
        post = AssociationValidationPost.cast(
          title: "Test Post",
          author_id: 1,
          category_id: 2
        )
        changeset = AssociationValidationPost.changeset(post)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "validates author_id foreign key" do
        post = AssociationValidationPost.cast({
          title: "Test Post",
          author_id: "invalid"
        })
        changeset = AssociationValidationPost.changeset(post)
          .validate_association_foreign_keys

        changeset.errors.should contain({"author_id", "association reference not found"})
      end

      it "validates category_id foreign key" do
        post = AssociationValidationPost.cast({
          title: "Test Post",
          category_id: 0
        })
        changeset = AssociationValidationPost.changeset(post)
          .validate_association_foreign_keys

        changeset.errors.should contain({"category_id", "association reference not found"})
      end
    end

    context "with edge cases" do
      it "handles empty hash gracefully" do
        user = AssociationValidationUser.new
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "handles symbol foreign keys" do
        # This might not happen in normal usage but tests robustness
        user = AssociationValidationUser.new
        changeset = AssociationValidationUser.changeset(user)

        # Should not crash even with unusual inputs
        changeset.validate_association_foreign_keys
      end

      it "handles very large integer values" do
        user = AssociationValidationUser.cast(
          name: "John Doe",
          company_id: Int32::MAX
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.should be_empty
      end

      it "handles float values that are equivalent to integers" do
        user = AssociationValidationUser.cast({
          name: "John Doe",
          company_id: 1.0
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        # Floats should be treated as invalid since they're not integers
        changeset.errors.should contain({"company_id", "association reference not found"})
      end
    end

    context "integration with changeset operations" do
      it "works with insert operations" do
        user = AssociationValidationUser.cast(
          name: "John Doe",
          company_id: 1
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.valid?.should be_true
      end

      it "works with update operations" do
        user = AssociationValidationUser.cast(
          id: 1,
          name: "John Doe",
          company_id: 1
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.valid?.should be_true
      end

      it "prevents invalid operations" do
        user = AssociationValidationUser.cast({
          name: "John Doe",
          company_id: "invalid_reference"
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.valid?.should be_false
        changeset.errors.should contain({"company_id", "association reference not found"})
      end
    end

    context "method chaining" do
      it "returns self for method chaining" do
        user = AssociationValidationUser.cast(name: "John Doe")
        changeset = AssociationValidationUser.changeset(user)
          .validate_required(:name)
          .validate_association_foreign_keys
          .validate_format(:email, /^\w+@\w+\.\w+$/)

        changeset.should be_a(Crecto::Changeset::Changeset(AssociationValidationUser))
      end

      it "can be called multiple times" do
        user = AssociationValidationUser.cast(
          name: "John Doe",
          company_id: 1
        )
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys
          .validate_association_foreign_keys

        changeset.errors.should be_empty
        changeset.valid?.should be_true
      end
    end

    context "error messages and localization" do
      it "provides consistent error messages" do
        user = AssociationValidationUser.cast({company_id: "invalid"})
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        error = changeset.errors.find { |error| error[0] == "company_id" }
        error.should_not be_nil
        error.not_nil![1].should eq("association reference not found")
      end

      it "handles multiple association types with the same error format" do
        user = AssociationValidationUser.cast({
          company_id: "invalid",
          manager_id: "invalid",
          profile_id: "invalid"
        })
        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        changeset.errors.size.should eq(3)
        changeset.errors.each do |error|
          error[1].should eq("association reference not found")
        end
      end
    end

    context "performance considerations" do
      it "handles models with many foreign keys efficiently" do
        # Create a user with all possible foreign keys
        user = AssociationValidationUser.cast(
          name: "John Doe",
          company_id: 1,
          manager_id: 2,
          profile_id: 3
        )

        # Time the validation (should be fast)
        start_time = Time.monotonic

        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        end_time = Time.monotonic

        # Should complete in reasonable time (less than 10ms)
        (end_time - start_time).total_milliseconds.should be < 10
        changeset.errors.should be_empty
      end

      it "handles models with no foreign keys efficiently" do
        user = AssociationValidationUser.cast(name: "John Doe")

        start_time = Time.monotonic

        changeset = AssociationValidationUser.changeset(user)
          .validate_association_foreign_keys

        end_time = Time.monotonic

        # Should complete very quickly (less than 1ms)
        (end_time - start_time).total_milliseconds.should be < 1
        changeset.errors.should be_empty
      end
    end
  end
end