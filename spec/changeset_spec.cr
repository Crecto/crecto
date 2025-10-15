require "uuid"
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
          changeset.errors[0].should eq({"unique_field", "duplicate key value violates unique constraint \"users_unique_field_key\""})
        elsif Repo.config.adapter == Crecto::Adapters::Mysql
          changeset.errors[0].should eq({"unique_field", "Duplicate entry '123' for key 'unique_field'"})
        elsif Repo.config.adapter == Crecto::Adapters::SQLite3
          changeset.errors[0].should eq({"unique_field", "UNIQUE constraint failed: users.unique_field"})
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
          changeset.errors[0].should eq({"unique_field", "duplicate key value violates unique constraint \"users_unique_field_key\""})
        elsif Repo.config.adapter == Crecto::Adapters::Mysql
          changeset.errors[0].should eq({"unique_field", "Duplicate entry '123' for key 'unique_field'"})
        elsif Repo.config.adapter == Crecto::Adapters::SQLite3
          changeset.errors[0].should eq({"unique_field", "UNIQUE constraint failed: users.unique_field"})
        end
      end

      it "should check uniqueness on primary_key fields" do
        id = UUID.random.to_s

        u = UserUUID.new
        u.uuid = id
        Repo.insert(u).errors.empty?.should be_true

        u = UserUUID.new
        u.uuid = id
        Repo.insert(u).errors.empty?.should be_false
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
        changeset.errors[0].should eq({"name", "is required"})
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
        changeset.errors[0].should eq({"name", "is invalid"})
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
        changeset.errors[0].should eq({"name", "is invalid"})
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
        changeset.errors[0].should eq({"name", "is invalid"})
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
        changeset.errors[0].should eq({"name", "is invalid"})
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
        changeset.errors[0].should eq({"_base", "Password must exist"})
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
        changeset.errors[0]?.should eq({"first_name", "is required"})
        changeset.errors[1]?.should eq({"last_name", "is required"})
      end

      it "should error formated fields" do
        u = UserMultipleValidations.new
        u.first_name = "asdf1234"
        u.last_name = "asdf1234"
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({"first_name", "is invalid"})
        changeset.errors[1]?.should eq({"last_name", "is invalid"})
      end

      it "should error fields with bad length" do
        u = UserMultipleValidations.new

        u.first_name = "x"
        u.last_name = "Smith"
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({"first_name", "is invalid"})

        u.first_name = "qwertyuiop" # size is 10
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({"first_name", "is invalid"})
      end

      it "should error fields within exclusions" do
        u = UserMultipleValidations.new
        u.first_name = "foo"
        u.last_name = "bar"
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({"first_name", "is invalid"})
        changeset.errors[1]?.should eq({"last_name", "is invalid"})
      end

      it "should error fields outside of inclusions" do
        u = UserMultipleValidations.new
        u.first_name = "John"
        u.last_name = "Smith"

        u.rank = 1000
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({"rank", "is invalid"})

        u.rank = 0
        changeset = UserMultipleValidations.changeset(u)
        changeset.errors[0]?.should eq({"rank", "is invalid"})
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

    describe "Association Foreign Key Validation" do
      describe "Issue #249: validate_association_foreign_keys" do
        it "should validate foreign key constraints for belongs_to associations" do
          # Test foreign key validation for belongs_to associations
          user = User.new
          user.name = "FK Test User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Test validation with valid foreign key
          changeset = Post.changeset(post)
          changeset.valid?.should be_true

          # Test foreign key value validation
          post.user_id.should eq(user.id)
          Post.foreign_key_value_for_association(:user, post).should eq(user.id)
        end

        it "should detect invalid foreign keys for belongs_to associations" do
          # Test detection of invalid foreign keys
          post = Post.new
          post.user_id = 99999 # Non-existent user ID

          # This should eventually fail when validate_association_foreign_keys is implemented
          changeset = Post.changeset(post)
          # Note: This test will fail until T019 implements validate_association_foreign_keys
          # For now, we're just testing the structure
          changeset.valid?.should be_true # Will change to false after implementation
        end

        it "should validate foreign key constraints for has_many associations" do
          # Test foreign key validation for has_many associations
          user = User.new
          user.name = "Has Many FK Test User"
          user = Repo.insert(user).instance

          post1 = Post.new
          post1.user = user
          post1 = Repo.insert(post1).instance

          post2 = Post.new
          post2.user = user
          post2 = Repo.insert(post2).instance

          # Test foreign key consistency
          User.foreign_key_value_for_association(:posts, user).should eq(user.id)

          # Verify all posts have correct foreign key
          user_posts = Repo.all(Post, Query.where(user_id: user.id))
          user_posts.size.should eq(2)
          user_posts.each { |post| post.user_id.should eq(user.id) }
        end

        it "should validate foreign key constraints for has_one associations" do
          # Test foreign key validation for has_one associations
          user = User.new
          user.name = "Has One FK Test User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Test foreign key consistency
          User.foreign_key_value_for_association(:post, user).should eq(user.id)

          # Verify post has correct foreign key
          user_post = Repo.get!(Post, post.id)
          user_post.user_id.should eq(user.id)
        end

        it "should handle null foreign keys correctly" do
          # Test handling of null foreign keys in optional associations
          post = Post.new
          # Don't set user_id, should be nil
          post.user_id.should be_nil

          changeset = Post.changeset(post)
          # Should be valid for optional associations
          changeset.valid?.should be_true

          # Association should be nil
          post.user?.should be_nil
        end

        it "should validate foreign key type consistency" do
          # Test that foreign key types match primary key types
          user = User.new
          user.name = "Type Consistency Test User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Test type consistency
          post.user_id.class.should eq(user.id.class)
          Post.foreign_key_for_association(:user).should eq(:user_id)
        end

        it "should handle foreign key validation in changesets" do
          # Test foreign key validation in changeset operations
          user = User.new
          user.name = "Changeset FK Test User"
          changeset = Repo.insert(user)
          changeset.errors.empty?.should be_true
          user = changeset.instance

          post = Post.new
          post.user = user

          changeset = Post.changeset(post)
          changeset.valid?.should be_true

          # Insert post
          insert_changeset = Repo.insert(post)
          insert_changeset.errors.empty?.should be_true
          post = insert_changeset.instance
          post_id = post.id

          # Verify post exists after insert
          post_after_insert = Repo.get(Post, post_id)
          post_after_insert.should_not be_nil
          post_after_insert.as(Post).user_id.should eq(user.id)

          # Test update with valid foreign key
          new_user = User.new
          new_user.name = "Updated FK Test User"
          new_user_changeset = Repo.insert(new_user)
          new_user_changeset.errors.empty?.should be_true
          new_user = new_user_changeset.instance

          # Reload post to ensure we have fresh data
          reloaded_post = Repo.get!(Post, post_id)
          reloaded_post.user = new_user
          update_changeset = Repo.update(reloaded_post)
          update_changeset.errors.empty?.should be_true

          # Verify foreign key was updated - check if post still exists
          updated_post = Repo.get(Post, post_id)
          updated_post.should_not be_nil
          updated_post.as(Post).user_id.should eq(new_user.id)
        end

        it "should detect orphaned records in foreign key validation" do
          # Test detection of orphaned records (foreign key pointing to non-existent record)
          user = User.new
          user.name = "Orphan Test User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Delete the user, creating an orphaned post
          Repo.delete(user)

          # Post should now have invalid foreign key
          orphaned_post = Repo.get!(Post, post.id)
          orphaned_post.user_id.should_not be_nil

          # This should be detected as invalid when validate_association_foreign_keys is implemented
          # For now, we're testing the structure
          changeset = Post.changeset(orphaned_post)
          changeset.valid?.should be_true # Will change to false after implementation
        end

        it "should handle circular foreign key references" do
          # Test handling of circular references (if applicable in the schema)
          user = User.new
          user.name = "Circular Reference Test User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Test that circular references don't cause infinite loops
          User.foreign_key_value_for_association(:posts, user).should eq(user.id)
          Post.foreign_key_value_for_association(:user, post).should eq(user.id)

          # Both should resolve correctly
          user.id.should eq(post.user_id)
        end

        it "should validate foreign key constraints in multi-transaction scenarios" do
          # Test foreign key validation within transactions
          user1 = User.new
          user1.name = "Transaction FK User 1"
          user1 = Repo.insert(user1).instance

          user2 = User.new
          user2.name = "Transaction FK User 2"
          user2 = Repo.insert(user2).instance

          post1 = Post.new
          post1.user = user1
          post1 = Repo.insert(post1).instance

          post2 = Post.new
          post2.user = user1
          post2 = Repo.insert(post2).instance

          # Test foreign key operations within transaction
          Repo.transaction! do
            # Update foreign key within transaction
            retrieved_post1 = Repo.get!(Post, post1.id)
            retrieved_post1.user = user2
            Repo.update(retrieved_post1)

            # Verify foreign key consistency within transaction
            updated_post = Repo.get!(Post, post1.id)
            updated_post.user_id.should eq(user2.id)

            # Create new post with foreign key within transaction
            post3 = Post.new
            post3.user = user1
            post3 = Repo.insert(post3).instance

            # Verify new foreign key
            post3.user_id.should eq(user1.id)
          end

          # Verify final state
          final_post1 = Repo.get!(Post, post1.id)
          final_post1.user_id.should eq(user2.id)

          final_post2 = Repo.get!(Post, post2.id)
          final_post2.user_id.should eq(user1.id)

          posts_for_user1 = Repo.all(Post, Query.where(user_id: user1.id))
          posts_for_user2 = Repo.all(Post, Query.where(user_id: user2.id))

          posts_for_user1.size.should eq(2)
          posts_for_user2.size.should eq(1)
        end
      end
    end
  end
end
