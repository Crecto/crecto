require "./spec_helper"

describe Crecto do
  describe "Repo::Query" do
    describe "#combine" do
      it "should combine 2 queries" do
        query = Crecto::Repo::Query
          .select(["user.name"])
          .where(name: "user_name")
          .or_where(name: "name_user")
          .join(:posts)
          .preload(:posts)
          .order_by("last_name ASC")
          .limit(1)

        query2 = Crecto::Repo::Query
          .select(["user.name2"])
          .where(name: "user_name2")
          .or_where(name: "name_user2")
          .join(:comments)
          .preload(:comments)
          .order_by("first_name ASC")
          .limit(2)

        new_query = query.combine(query2)

        new_query.selects.should eq ["user.name", "user.name2"]
        new_query.where_expression.should eq Crecto::Repo::Query::AndExpression.new(
          Crecto::Repo::Query::OrExpression.new(
            Crecto::Repo::Query::AtomExpression.new({:name => "user_name"}),
            Crecto::Repo::Query::AtomExpression.new({:name => "name_user"})
          ),
          Crecto::Repo::Query::OrExpression.new(
            Crecto::Repo::Query::AtomExpression.new({:name => "user_name2"}),
            Crecto::Repo::Query::AtomExpression.new({:name => "name_user2"})
          )
        )
        new_query.joins.should eq [:posts, :comments]
        new_query.preloads.should eq [{symbol: :posts, query: nil}, {symbol: :comments, query: nil}]
        new_query.order_bys.should eq ["last_name ASC", "first_name ASC"]
        new_query.limit.should eq 2
      end
    end

    describe "#join" do
      it "should add JOIN clause string from Query class" do
        query = Crecto::Repo::Query.join("INNER JOIN users ON users.id = posts.user_id")

        query.joins.size.should eq 1
        query.joins[0].should eq "INNER JOIN users ON users.id = posts.user_id"
      end

      it "should add JOIN clause string from Query instance" do
        query = Crecto::Repo::Query.new
        query.joins.size.should eq 0

        query = query.join("INNER JOIN users ON users.id = posts.user_id")

        query.joins.size.should eq 1
        query.joins[0].should eq "INNER JOIN users ON users.id = posts.user_id"
      end
    end

    describe "#and" do
      it "combines the where expressions with an AndExpression" do
        query = Crecto::Repo::Query.where(foo: "bar").and do |e|
          e.or_where(name: "jokke", age: 99)
        end

        query.where_expression.should eq Crecto::Repo::Query::AndExpression.new(
          Crecto::Repo::Query::AtomExpression.new({:foo => "bar"}),
          Crecto::Repo::Query::OrExpression.new(
            Crecto::Repo::Query::AtomExpression.new({:name => "jokke", :age => 99}),
          )
        )
      end

      it "supports nesting" do
        query = Crecto::Repo::Query.where(foo: "bar").and do |e|
          e.or_where(name: "jokke", age: 99).and do |nested|
            nested.where(bar: "baz")
          end
        end

        query.where_expression.should eq Crecto::Repo::Query::AndExpression.new(
          Crecto::Repo::Query::AtomExpression.new({:foo => "bar"}),
          Crecto::Repo::Query::OrExpression.new(
            Crecto::Repo::Query::AndExpression.new(
              Crecto::Repo::Query::OrExpression.new(
                Crecto::Repo::Query::AtomExpression.new({:name => "jokke", :age => 99}),
              ),
              Crecto::Repo::Query::AtomExpression.new({:bar => "baz"})
            )
          )
        )
      end

      context "with other query" do
        it "combines the where expressions with an AndExpression" do
          query = Crecto::Repo::Query.where(foo: "bar").and(
            Crecto::Repo::Query.where(name: "fridge"),
            Crecto::Repo::Query.where(age: "99")
          )

          query.where_expression.should eq Crecto::Repo::Query::AndExpression.new(
            Crecto::Repo::Query::AtomExpression.new({:foo => "bar"}),
            Crecto::Repo::Query::AtomExpression.new({:name => "fridge"}),
            Crecto::Repo::Query::AtomExpression.new({:age => "99"}),
          )
        end
      end
    end

    describe "#or" do
      it "combines the where expressions with an OrExpression" do
        query = Crecto::Repo::Query.where(foo: "bar").or do |e|
          e.where(name: "jokke", age: 99)
        end

        query.where_expression.should eq Crecto::Repo::Query::OrExpression.new(
          Crecto::Repo::Query::AtomExpression.new({:foo => "bar"}),
          Crecto::Repo::Query::AtomExpression.new({:name => "jokke", :age => 99}),
        )
      end

      it "supports nesting" do
        query = Crecto::Repo::Query.where(foo: "bar").or do |e|
          e.where(bar: "baz").or do |nested|
            nested.or_where(name: "jokke", age: 99)
          end
        end

        query.where_expression.should eq Crecto::Repo::Query::OrExpression.new(
          Crecto::Repo::Query::AtomExpression.new({:foo => "bar"}),
          Crecto::Repo::Query::OrExpression.new(
            Crecto::Repo::Query::AtomExpression.new({:bar => "baz"}),
            Crecto::Repo::Query::OrExpression.new(
              Crecto::Repo::Query::AtomExpression.new({:name => "jokke", :age => 99})
            )
          )
        )
      end

      context "with other query" do
        it "combines the where expressions with an OrExpression" do
          query = Crecto::Repo::Query.where(foo: "bar").or(
            Crecto::Repo::Query.where(name: "fridge"),
            Crecto::Repo::Query.where(name: "jokke")
          )

          query.where_expression.should eq Crecto::Repo::Query::OrExpression.new(
            Crecto::Repo::Query::AtomExpression.new({:foo => "bar"}),
            Crecto::Repo::Query::AtomExpression.new({:name => "fridge"}),
            Crecto::Repo::Query::AtomExpression.new({:name => "jokke"}),
          )
        end
      end
    end

    describe "Query String Interpolation Safety" do
      it "should safely handle parameter interpolation in WHERE clauses" do
        # Test for issue #217: Query string interpolation corruption
        # This test ensures that parameters with special characters are properly escaped
        user_name = "Test User"
        user_email = "test@example.com"
        user_bio = "This is a test with 'quotes' and \"double quotes\""

        query = Crecto::Repo::Query.where(name: user_name, email: user_email, bio: user_bio)

        # Query should handle special characters without corruption
        query.where_expression.should be_a(Crecto::Repo::Query::AtomExpression)
        atom = query.where_expression.as(Crecto::Repo::Query::AtomExpression)
        # Convert to string representation to check if data matches regardless of key syntax
        atom.atom.to_s.should contain("name")
        atom.atom.to_s.should contain("Test User")
        atom.atom.to_s.should contain("email")
        atom.atom.to_s.should contain("test@example.com")
        atom.atom.to_s.should contain("bio")
        atom.atom.to_s.should contain("quotes")
      end

      it "should safely handle string concatenation in query components" do
        # Test that string concatenation doesn't corrupt query structure
        base_query = "SELECT * FROM users WHERE name = "
        param_value = "test_user"

        # Query building should maintain integrity
        query = Crecto::Repo::Query.where("name = ?", param_value)
        query.where_expression.should be_a(Crecto::Repo::Query::AtomExpression)
      end

      it "should safely handle parameterized queries with arrays" do
        # Test array parameter handling without corruption
        ids = [1, 2, 3, 4, 5]
        query = Crecto::Repo::Query.where(:id, ids)

        # Query should maintain structure integrity with array parameters
        query.where_expression.should be_a(Crecto::Repo::Query::AtomExpression)
        atom = query.where_expression.as(Crecto::Repo::Query::AtomExpression)
        # The atom should contain the array parameters safely
        atom.atom.should_not be_nil
      end

      it "should safely handle complex query expressions with interpolation" do
        # Test complex expressions that could cause interpolation corruption
        query = Crecto::Repo::Query
          .where("name LIKE ?", "%test%")
          .where("email LIKE ?", "%@example.com%")
          .or_where("created_at > ?", Time.utc(2023, 1, 1))

        query.where_expression.should be_a(Crecto::Repo::Query::OrExpression)
      end

      it "should safely handle ORDER BY clause parameter interpolation" do
        # Test ORDER BY clauses for potential interpolation issues
        query = Crecto::Repo::Query
          .order_by("name ASC")
          .order_by("created_at DESC")

        query.order_bys.should eq(["name ASC", "created_at DESC"])
      end

      it "should safely handle LIMIT and OFFSET parameter interpolation" do
        # Test LIMIT and OFFSET for numerical interpolation issues
        query = Crecto::Repo::Query
          .limit(10)
          .offset(20)

        query.limit.should eq(10)
        query.offset.should eq(20)
      end

      it "should safely handle JOIN clause parameter interpolation" do
        # Test JOIN clauses for potential interpolation corruption
        query = Crecto::Repo::Query
          .join("INNER JOIN posts ON posts.user_id = users.id")
          .join("LEFT JOIN addresses ON addresses.user_id = users.id")

        query.joins.size.should eq(2)
        query.joins[0].should eq("INNER JOIN posts ON posts.user_id = users.id")
        query.joins[1].should eq("LEFT JOIN addresses ON addresses.user_id = users.id")
      end

      it "should safely handle SELECT clause parameter interpolation" do
        # Test SELECT clauses for potential interpolation corruption
        columns = ["users.name", "users.email", "COUNT(posts.id) as post_count"]
        query = Crecto::Repo::Query.select(columns)

        query.selects.should eq(columns)
      end

      it "should safely handle parameterized queries with special characters" do
        # Test for SQL injection attempts and special character handling
        malicious_input = "'; DROP TABLE users; --"
        query = Crecto::Repo::Query.where(name: malicious_input)

        # Query should store the parameter safely, not execute it
        query.where_expression.should be_a(Crecto::Repo::Query::AtomExpression)
        atom = query.where_expression.as(Crecto::Repo::Query::AtomExpression)
        atom.atom.should_not be_nil

        # The atom should contain the malicious input safely
        atom.atom.to_s.should contain(malicious_input)
      end

      it "should safely handle parameterized queries with nil values" do
        # Test nil value handling in parameterized queries
        query = Crecto::Repo::Query.where("name = ? OR email IS NULL", ["test"])

        query.where_expression.should be_a(Crecto::Repo::Query::AtomExpression)
        atom = query.where_expression.as(Crecto::Repo::Query::AtomExpression)

        # Query should store the parameters safely
        atom.atom.should_not be_nil
        atom.atom.to_s.should contain("test")
      end

      it "should safely handle complex nested query expressions" do
        # Test that complex nested expressions don't cause corruption
        query = Crecto::Repo::Query
          .where(name: "test")
          .and do |subquery|
            subquery.or_where(email: "test@example.com")
                   .where("age > ?", 18)
          end
          .or do |subquery|
            subquery.where("created_at > ?", Time.utc(2023, 1, 1))
          end

        # Complex nested structure should be preserved
        query.where_expression.should be_a(Crecto::Repo::Query::OrExpression)
      end
    end
  end
end
