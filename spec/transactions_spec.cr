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

        puts "\nusers: #{Repo.all(User).size}\n"
        sleep 0.1

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
          Repo.transaction! do |tx|
            tx.insert!(user)
          end
        end
      end

      it "with a valid insert, should insert the record" do
        user = User.new
        user.name = "this should insert in the transaction"

        Repo.transaction! do |tx|
          tx.insert(user)
        end

        users = Repo.all(User, Query.where(name: "this should insert in the transaction"))
        users.size.should be > 0
      end

      it "with a valid delete, should delete the record" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        user = quick_create_user("this should delete")

        Repo.transaction! do |tx|
          tx.delete!(user)
        end

        users = Repo.all(User, Query.where(id: user.id))
        users.any?.should eq(false)
      end

      it "with a valid delete_all, should delete all records" do
        2.times do
          quick_create_user("test")
        end

        Repo.delete_all(Post)

        Repo.transaction! do |tx|
          tx.delete_all(User)
        end

        users = Repo.all(User)
        users.size.should eq(0)
      end

      it "with a valid update, should update the record" do
        user = quick_create_user("this will change 89ffsf")

        user.name = "this should have changed 89ffsf"

        Repo.transaction! do |tx|
          tx.update(user)
        end

        user = Repo.get!(User, user.id)
        user.name.should eq("this should have changed 89ffsf")
      end

      it "with a valid update_all, should update all records" do
        quick_create_user_with_things("testing_update_all", 123)
        quick_create_user_with_things("testing_update_all", 123)
        quick_create_user_with_things("testing_update_all", 123)

        Repo.transaction! do |tx|
          tx.update_all(User, Query.where(name: "testing_update_all"), {things: 9494})
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

        Repo.transaction! do |tx|
          tx.insert!(insert_user)
          tx.delete!(delete_user)
          tx.delete_all(Post)
          tx.update!(update_user)
          tx.update_all(User, Query.where(name: "perform_all"), {name: "perform_all_io2oj999"})
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

      # This only works for postgres for now
      {% begin %}
        {{ flag?(:pg) ? :it.id : :pending.id }} "allows reading records inserted inside the transaction" do
          insert_user = User.new
          insert_user.name = "insert_user"

          Repo.transaction! do |tx|
            id = tx.insert!(insert_user).instance.id
            tx.get(User, id).should_not eq(nil)
            tx.get!(User, id).should_not eq(nil)
            tx.get(User, id, Query.new).should_not eq(nil)
            tx.get!(User, id, Query.new).should_not eq(nil)
            tx.get_by(User, id: id).should_not eq(nil)
            tx.get_by!(User, id: id).should_not eq(nil)
            tx.get_by(User, id: id).should_not eq(nil)
            tx.get_by!(User, id: id).should_not eq(nil)
            tx.get_by(User, Query.where(id: id)).should_not eq(nil)
            tx.get_by!(User, Query.where(id: id)).should_not eq(nil)
            tx.all(User, Query.where(id: id)).first.should_not eq(nil)
            tx.all(User, Query.where(id: id), preload: [] of Symbol).first.should_not eq(nil)
          end
        end
      {% end %}

      it "allows nesting transactions" do
        Repo.delete_all(Post)
        Repo.delete_all(User)

        insert_user = User.new
        insert_user.name = "nested_transactions_insert_user"
        invalid_user = User.new
        delete_user = quick_create_user("nested_transactions_delete_user")

        Repo.transaction! do |tx|
          tx.insert!(insert_user)

          expect_raises Crecto::InvalidChangeset do
            Repo.transaction! do |inner_tx|
              inner_tx.delete!(delete_user)
              inner_tx.insert!(invalid_user)
            end
          end
        end

        # check insert happened
        Repo.all(User, Query.where(name: "nested_transactions_insert_user")).size.should eq 1

        # check delete didn't happen
        Repo.all(User, Query.where(name: "nested_transactions_delete_user")).size.should eq 1
      end
    end
  end
end
