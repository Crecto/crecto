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
        new_query.wheres.should eq [{:name => "user_name"}, {:name => "user_name2"}]
        new_query.or_wheres.should eq [{:name => "name_user"}, {:name => "name_user2"}]
        new_query.joins.should eq [:posts, :comments]
        new_query.preloads.should eq [{symbol: :posts, query: nil}, {symbol: :comments, query: nil}]
        new_query.order_bys.should eq ["last_name ASC", "first_name ASC"]
        new_query.limit.should eq 2
      end
    end
  end
end
