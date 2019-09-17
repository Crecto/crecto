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
  end
end
