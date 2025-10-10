require "./spec_helper"
require "./helper_methods"

describe Crecto do
  describe "Repo" do
    describe "#transaction" do
      it "with an invalid changeset, should have errors" do
        user = User.new

        multi = Multi.new
        multi.insert(user)

        multi = Repo.transaction(multi)
        multi.errors[0][:field].should eq("name")
        multi.errors[0][:message].should eq("is required")
      end

      it "with a valid insert, should insert the record" do
        user = User.new
        user.name = "this should insert in the transaction"

        multi = Multi.new
        multi.insert(user)
        multi = Repo.transaction(multi)

        users = Repo.all(User, Query.where(name: "this should insert in the transaction"))
        users.size.should be > 0
      end

      it "with a valid delete, should delete the record" do
        # Skip this spec for sqlite since it randomly fails on travis
        next if Repo.config.adapter == Crecto::Adapters::SQLite3

        Repo.delete_all(Post)
        Repo.delete_all(User)

        user = quick_create_user("this should delete")

        multi = Multi.new
        multi.delete(user)
        Repo.transaction(multi)

        users = Repo.all(User, Query.where(id: user.id))
        users.any?.should eq(false)
      end

      it "with a valid delete_all, should delete all records" do
        # Skip this spec for sqlite since it randomly fails on travis
        next if Repo.config.adapter == Crecto::Adapters::SQLite3

        2.times do
          quick_create_user("test")
        end

        Repo.delete_all(Post)

        multi = Multi.new
        multi.delete_all(User)
        Repo.transaction(multi)

        users = Repo.all(User)
        users.size.should eq(0)
      end

      it "with a valid update, should update the record" do
        user = quick_create_user("this will change 89ffsf")

        user.name = "this should have changed 89ffsf"

        multi = Multi.new
        multi.update(user)
        Repo.transaction(multi)

        user = Repo.get!(User, user.id)
        user.name.should eq("this should have changed 89ffsf")
      end

      it "with a valid update_all, should update all records" do
        quick_create_user_with_things("testing_update_all", 123)
        quick_create_user_with_things("testing_update_all", 123)
        quick_create_user_with_things("testing_update_all", 123)

        multi = Multi.new
        multi.update_all(User, Query.where(name: "testing_update_all"), {things: 9494})
        Repo.transaction(multi)

        Repo.all(User, Query.where(things: 123)).size.should eq 0
        Repo.all(User, Query.where(things: 9494)).size.should eq 3
      end

      it "should perform all transaction types" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        delete_user = quick_create_user("all_transactions_delete_user")
        update_user = quick_create_user("all_transactions_update_user")
        update_user.name = "all_transactions_update_user_ojjl2032"
        quick_create_post(quick_create_user("perform_all"))
        quick_create_post(quick_create_user("perform_all"))
        insert_user = User.new
        insert_user.name = "all_transactions_insert_user"

        multi = Multi.new
        multi.insert(insert_user)
        multi.delete(delete_user)
        multi.delete_all(Post)
        multi.update(update_user)
        multi.update_all(User, Query.where(name: "perform_all"), {name: "perform_all_io2oj999"})
        Repo.transaction(multi)

        multi.errors.any?.should eq false

        # check insert happened
        Repo.all(User, Query.where(name: "all_transactions_insert_user")).size.should eq 1

        # check delete happened
        Repo.all(User, Query.where(name: "all_transactions_delete_user")).size.should eq 0

        # check delete all happened
        Repo.all(Post).size.should eq 0

        # check update happened
        Repo.all(User, Query.where(name: "all_transactions_update_user")).size.should eq 0
        Repo.all(User, Query.where(name: "all_transactions_update_user_ojjl2032")).size.should eq 1

        # check update all happened
        Repo.all(User, Query.where(name: "perform_all")).size.should eq 0
        Repo.all(User, Query.where(name: "perform_all_io2oj999")).size.should eq 2
      end

      it "should rollback and not perform any of the transactions with an invalid query" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        delete_user = quick_create_user("all_transactions_delete_user")
        update_user = quick_create_user("all_transactions_update_user")
        update_user.name = "all_transactions_update_user_ojjl2032"
        quick_create_post(quick_create_user("perform_all"))
        quick_create_post(quick_create_user("perform_all"))
        insert_user = User.new
        insert_user.name = "all_transactions_insert_user"

        invalid_user = User.new

        multi = Multi.new
        multi.insert(insert_user)
        multi.delete(delete_user)
        multi.delete_all(Post)
        multi.update(update_user)
        multi.update_all(User, Query.where(name: "perform_all"), {name: "perform_all_io2oj999"})
        multi.insert(invalid_user)
        Repo.transaction(multi)

        multi.errors.any?.should eq true
        multi.errors[0][:field].should eq "name"
        multi.errors[0][:message].should eq "is required"
        multi.errors[0][:queryable].should eq "User"

        # check insert didn't happen
        Repo.all(User, Query.where(name: "all_transactions_insert_user")).size.should eq 0

        # check delete didn't happen
        Repo.all(User, Query.where(name: "all_transactions_delete_user")).size.should eq 1

        # check delete all didn't happen
        Repo.all(Post).size.should eq 2

        # check update didn't happen
        Repo.all(User, Query.where(name: "all_transactions_update_user")).size.should eq 1
        Repo.all(User, Query.where(name: "all_transactions_update_user_ojjl2032")).size.should eq 0

        # check update all didn't happen
        Repo.all(User, Query.where(name: "perform_all")).size.should eq 2
        Repo.all(User, Query.where(name: "perform_all_io2oj999")).size.should eq 0
      end
    end

    describe "#transaction!" do
      it "with an invalid changeset using #insert!, should raise" do
        user = User.new

        expect_raises Crecto::InvalidChangeset do
          Repo.transaction! do
            Repo.insert!(user)
          end
        end
      end

      it "with a valid insert, should insert the record" do
        user = User.new
        user.name = "this should insert in the transaction"

        Repo.transaction! do
          Repo.insert(user)
        end

        users = Repo.all(User, Query.where(name: "this should insert in the transaction"))
        users.size.should be > 0
      end

      it "with a valid delete, should delete the record" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        user = quick_create_user("this should delete")

        Repo.transaction! do
          Repo.delete!(user)
        end

        users = Repo.all(User, Query.where(id: user.id))
        users.any?.should eq(false)
      end

      it "with a valid delete_all, should delete all records" do
        2.times do
          quick_create_user("test")
        end

        Repo.delete_all(Post)

        Repo.transaction! do
          Repo.delete_all(User)
        end

        users = Repo.all(User)
        users.size.should eq(0)
      end

      it "with a valid update, should update the record" do
        user = quick_create_user("this will change 89ffsf")

        user.name = "this should have changed 89ffsf"

        Repo.transaction! do
          Repo.update(user)
        end

        user = Repo.get!(User, user.id)
        user.name.should eq("this should have changed 89ffsf")
      end

      it "with a valid update_all, should update all records" do
        quick_create_user_with_things("testing_update_all", 123)
        quick_create_user_with_things("testing_update_all", 123)
        quick_create_user_with_things("testing_update_all", 123)

        Repo.transaction! do
          Repo.update_all(User, Query.where(name: "testing_update_all"), {things: 9494})
        end

        Repo.all(User, Query.where(things: 123)).size.should eq 0
        Repo.all(User, Query.where(things: 9494)).size.should eq 3
      end

      it "should perform all transaction types" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        delete_user = quick_create_user("all_transactions_delete_user")
        update_user = quick_create_user("all_transactions_update_user")
        update_user.name = "all_transactions_update_user_ojjl2032"
        quick_create_post(quick_create_user("perform_all"))
        quick_create_post(quick_create_user("perform_all"))
        insert_user = User.new
        insert_user.name = "all_transactions_insert_user"

        Repo.transaction! do
          Repo.insert!(insert_user)
          Repo.delete!(delete_user)
          Repo.delete_all(Post)
          Repo.update!(update_user)
          Repo.update_all(User, Query.where(name: "perform_all"), {name: "perform_all_io2oj999"})
        end

        # check insert happened
        Repo.all(User, Query.where(name: "all_transactions_insert_user")).size.should eq 1

        # check delete happened
        Repo.all(User, Query.where(name: "all_transactions_delete_user")).size.should eq 0

        # check delete all happened
        Repo.all(Post).size.should eq 0

        # check update happened
        Repo.all(User, Query.where(name: "all_transactions_update_user")).size.should eq 0
        Repo.all(User, Query.where(name: "all_transactions_update_user_ojjl2032")).size.should eq 1

        # check update all happened
        Repo.all(User, Query.where(name: "perform_all")).size.should eq 0
        Repo.all(User, Query.where(name: "perform_all_io2oj999")).size.should eq 2
      end

      it "should rollback and not perform any of the transactions with an invalid query" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        delete_user = quick_create_user("all_transactions_delete_user")
        update_user = quick_create_user("all_transactions_update_user")
        update_user.name = "all_transactions_update_user_ojjl2032"
        quick_create_post(quick_create_user("perform_all"))
        quick_create_post(quick_create_user("perform_all"))
        insert_user = User.new
        insert_user.name = "all_transactions_insert_user"

        invalid_user = User.new

        expect_raises Crecto::InvalidChangeset do
          Repo.transaction! do |tx|
            tx.insert!(insert_user)
            tx.delete!(delete_user)
            tx.delete_all(Post)
            tx.update!(update_user)
            tx.update_all(User, Query.where(name: "perform_all"), {name: "perform_all_io2oj999"})
            tx.insert!(invalid_user)
          end
        end

        # check insert didn't happen
        Repo.all(User, Query.where(name: "all_transactions_insert_user")).size.should eq 0

        # check delete didn't happen
        Repo.all(User, Query.where(name: "all_transactions_delete_user")).size.should eq 1

        # check delete all didn't happen
        Repo.all(Post).size.should eq 2

        # check update didn't happen
        Repo.all(User, Query.where(name: "all_transactions_update_user")).size.should eq 1
        Repo.all(User, Query.where(name: "all_transactions_update_user_ojjl2032")).size.should eq 0

        # check update all didn't happen
        Repo.all(User, Query.where(name: "perform_all")).size.should eq 2
        Repo.all(User, Query.where(name: "perform_all_io2oj999")).size.should eq 0
      end
    end

    describe "Multi-Transaction Association Operations" do
      describe "Issue #249: Association operations in multi-transaction scenarios" do
        it "should handle belongs_to associations within transactions" do
          # Test for issue #249: Associations should work correctly in multi-transaction scenarios
          user = User.new
          user.name = "Transaction Test User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Now test association operations within a transaction
          Repo.transaction! do
            # Verify association is accessible within transaction
            retrieved_post = Repo.get!(Post, post.id)
            retrieved_post.user_id.should eq(user.id)

            # Load the association explicitly since get! doesn't preload
            associated_user = Repo.get_association!(retrieved_post, :user)
            associated_user.should_not be_nil
            associated_user.as(User).name.should eq("Transaction Test User")

            # Update association within transaction
            new_user = User.new
            new_user.name = "New Association User"
            new_user = Repo.insert(new_user).instance
            retrieved_post.user = new_user
            Repo.update(retrieved_post)

            # Verify association was updated
            updated_post = Repo.get!(Post, post.id)
            updated_post.user_id.should eq(new_user.id)
          end

          # Verify final state outside transaction
          final_post = Repo.get!(Post, post.id)
          final_associated_user = Repo.get_association!(final_post, :user)
          final_associated_user.should_not be_nil
          final_associated_user.as(User).name.should eq("New Association User")
        end

        it "should handle has_many associations within transactions" do
          # Test has_many associations in multi-transaction scenarios
          user = User.new
          user.name = "Has Many Transaction User"
          user = Repo.insert(user).instance

          post1 = Post.new
          post1.user = user
          post1 = Repo.insert(post1).instance

          post2 = Post.new
          post2.user = user
          post2 = Repo.insert(post2).instance

          # Test has_many operations within transaction
          Repo.transaction! do
            retrieved_user = Repo.get!(User, user.id)

            # Preload associations within transaction
            users = Repo.all(User, Query.where(id: user.id).preload(:posts))
            users.size.should eq(1)
            users[0].posts.size.should eq(2)

            # Add new post to association within transaction
            post3 = Post.new
            post3.user = retrieved_user
            post3 = Repo.insert(post3).instance

            # Verify association count increased
            users_with_posts = Repo.all(User, Query.where(id: user.id).preload(:posts))
            users_with_posts[0].posts.size.should eq(3)
          end

          # Verify final state
          final_user = Repo.get!(User, user.id)
          final_posts = Repo.all(Post, Query.where(user_id: final_user.id))
          final_posts.size.should eq(3)
        end

        it "should handle has_one associations within transactions" do
          # Test has_one associations in multi-transaction scenarios
          user = User.new
          user.name = "Has One Transaction User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Test has_one operations within transaction
          Repo.transaction! do
            retrieved_user = Repo.get!(User, user.id)

            # Preload has_one association within transaction
            users = Repo.all(User, Query.where(id: user.id).preload(:post))
            users.size.should eq(1)
            users[0].post?.should_not be_nil
            users[0].post.as(Post).user_id.should eq(user.id)

            # Update has_one association within transaction
            new_post = Post.new
            new_post.user = retrieved_user
            new_post = Repo.insert(new_post).instance

            # Verify association was updated
            users_with_post = Repo.all(User, Query.where(id: user.id).preload(:post))
            users_with_post[0].post?.should_not be_nil
            users_with_post[0].post.as(Post).id.should eq(new_post.id)
          end
        end

        it "should handle association foreign key validation within transactions" do
          # Test foreign key validation for associations within transactions
          user = User.new
          user.name = "Foreign Key Test User"
          user = Repo.insert(user).instance

          post = Post.new
          post.user = user
          post = Repo.insert(post).instance

          # Test foreign key consistency within transaction
          Repo.transaction! do
            retrieved_post = Repo.get!(Post, post.id)
            retrieved_post.user_id.should eq(user.id)

            # Test association method calls within transaction
            Post.klass_for_association(:user).should eq(User)
            Post.foreign_key_for_association(:user).should eq(:user_id)
            Post.foreign_key_value_for_association(:user, retrieved_post).should eq(user.id)
          end
        end

        it "should handle complex multi-transaction association scenarios" do
          # Test complex scenarios with multiple association operations
          user1 = User.new
          user1.name = "Complex User 1"
          user1 = Repo.insert(user1).instance

          user2 = User.new
          user2.name = "Complex User 2"
          user2 = Repo.insert(user2).instance

          post1 = Post.new
          post1.user = user1
          post1 = Repo.insert(post1).instance

          post2 = Post.new
          post2.user = user1
          post2 = Repo.insert(post2).instance

          # Test complex multi-transaction scenario
          Repo.transaction! do
            # Update first post to use different user
            retrieved_post1 = Repo.get!(Post, post1.id)
            retrieved_post1.user = user2
            Repo.update(retrieved_post1)

            # Create new post for first user
            post3 = Post.new
            post3.user = user1
            post3 = Repo.insert(post3).instance

            # Verify all associations are consistent
            user1_posts = Repo.all(Post, Query.where(user_id: user1.id))
            user2_posts = Repo.all(Post, Query.where(user_id: user2.id))

            user1_posts.size.should eq(2)
            user2_posts.size.should eq(1)

            # Test preloaded associations within transaction
            users = Repo.all(User, Query.where("id IN (?, ?)", [user1.id, user2.id]).preload(:posts))
            users.size.should eq(2)

            user1_record = users.find { |u| u.id == user1.id }
            user2_record = users.find { |u| u.id == user2.id }

            user1_record.not_nil!.posts.size.should eq(2)
            user2_record.not_nil!.posts.size.should eq(1)
          end
        end

        it "should handle transaction rollback with association operations" do
          # Test that association operations are properly rolled back
          initial_user_count = Repo.all(User).size
          initial_post_count = Repo.all(Post).size

          # Expect transaction to rollback
          expect_raises Crecto::InvalidChangeset do
            Repo.transaction! do |tx|
              # Create user inside transaction
              user = User.new
              user.name = "Rollback Test User"
              user = tx.insert!(user).instance

              # Create valid post association
              post = Post.new
              post.user = user
              post = tx.insert!(post).instance

              # Verify association was created
              retrieved_post = tx.get!(Post, post.id)
              retrieved_post.user_id.should eq(user.id)

              # Create invalid user to cause rollback
              invalid_user = User.new
              tx.insert!(invalid_user)
            end
          end

          # Verify rollback worked - counts should be back to original
          final_user_count = Repo.all(User).size
          final_post_count = Repo.all(Post).size

          final_user_count.should eq(initial_user_count)
          final_post_count.should eq(initial_post_count)
        end

        it "should handle nested transactions with associations" do
          # Test nested transaction scenarios with associations
          user = User.new
          user.name = "Nested Transaction User"
          user = Repo.insert(user).instance

          # Outer transaction
          Repo.transaction! do
            post1 = Post.new
            post1.user = user
            post1 = Repo.insert(post1).instance

            # Inner transaction (savepoint)
            Repo.transaction! do
              post2 = Post.new
              post2.user = user
              post2 = Repo.insert(post2).instance

              # Verify association in inner transaction
              user_posts = Repo.all(Post, Query.where(user_id: user.id))
              user_posts.size.should eq(2)
            end

            # Verify after inner transaction
            user_posts = Repo.all(Post, Query.where(user_id: user.id))
            user_posts.size.should eq(2)
          end

          # Verify final state
          final_posts = Repo.all(Post, Query.where(user_id: user.id))
          final_posts.size.should eq(2)
        end
      end
    end
  end
end
