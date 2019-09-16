module Crecto
  module Repo
    # Queries are used to retrieve and manipulate data from a repository.  Syntax is much like that of ActiveRecord:
    #
    # `Query.select('id').where(name: "fred").join(:posts).order_by("users.name").limit(1).offset(4)`
    #
    class Query
      abstract class WhereExpression
        abstract def and(other : WhereExpression) : WhereExpression
        abstract def or(other : WhereExpression) : WhereExpression

        getter? empty = false

        def and(other : WhereType)
          and(AtomExpression.new(other))
        end

        def or(other : WhereType)
          or(AtomExpression.new(other))
        end

        def and
          and(yield InitialExpression.new)
        end

        def or
          or(yield InitialExpression.new)
        end

        {% for method in %i[where or_where] %}
          {% op = method == :where ? :and : :or %}

          # Query#{{ method.id }} with Key => Value pair(s)
          #
          # ```
          # query.{{ method.id }}(name: "Thor", age: 60)
          # ```
          def {{ method.id }}(**wheres)
            wheres = wheres.to_h
            {{op.id}}(Hash.zip(wheres.keys, wheres.values))
          end

          # Query#{{ method.id }} with a String and Array(DbValue)
          #
          # ```
          # query.{{ method.id }}("users.id > ?", [10])
          # ```
          def {{ method.id }}(where_string : String, params : Array(DbValue))
            {{op.id}}({ clause: where_string, params: params.map { |p| p.as(DbValue) }})
          end

          # Query#{{ method.id }} with a Symbol and DbValue
          #
          # ```
          # query.{{ method.id }}(:name, "Conan")
          # ```
          def {{ method.id }}(where_sym : Symbol, param : DbValue)
            {{op.id}}({where_sym => param.as(DbValue)})
          end

          # Query#{{ method.id }} with a Symbol and Array(DbValue)
          #
          # ```
          # query.{{ method.id }}(:name, ["Conan", "Zeus"])
          # ```
          def {{ method.id }}(where_sym : Symbol, params : Array(DbValue))
            w = {} of Symbol => Array(DbValue)
            w[where_sym] = params.map { |x| x.as(DbValue) }
            {{op.id}}(w)
          end

          # Query#{{ method.id }} with a String
          #
          # ```
          # query.{{ method.id }}("name IS NOT NULL")
          # ```
          def {{ method.id }}(where_string : String)
            {{ method.id }}(where_string, Array(String).new)
          end

          # Query.{{ method.id }} with a String and String parameter
          #
          # ```
          # query.{{ method.id }}("name LIKE ?", "%phyllis%")
          # ```
          def {{ method.id }}(where_string : String, param : DbValue | PkeyValue)
            {{ method.id }}(where_string, [param])
          end
        {% end %}
      end

      class AndExpression < WhereExpression
        getter expressions : Array(WhereExpression)

        def initialize(*expressions)
          @expressions = expressions.map(&.as(WhereExpression)).to_a
        end

        def ==(other : self)
          expressions == other.expressions
        end

        def and(other : WhereExpression) : WhereExpression
          @expressions << other
          self
        end

        def or(other : WhereExpression) : WhereExpression
          OrExpression.new(self, other)
        end
      end

      class OrExpression < WhereExpression
        getter expressions : Array(WhereExpression)

        def initialize(*expressions)
          @expressions = expressions.map(&.as(WhereExpression)).to_a
        end

        def ==(other : self)
          expressions == other.expressions
        end

        def and(other : WhereExpression) : WhereExpression
          last = @expressions.pop
          last = AndExpression.new(self.class.new(last)) if last.is_a?(AtomExpression)
          @expressions << last.and(other)
          self
        end

        def or(other : WhereExpression) : WhereExpression
          @expressions << other
          self
        end
      end

      class AtomExpression < WhereExpression
        getter atom : WhereType

        def initialize(@atom)
        end

        def ==(other : self)
          atom == other.atom
        end

        def and(other : WhereExpression) : WhereExpression
          AndExpression.new(self, other)
        end

        def or(other : WhereExpression) : WhereExpression
          OrExpression.new(self, other)
        end
      end

      class InitialExpression < WhereExpression
        @empty = true

        def and(other : WhereExpression) : WhereExpression
          AndExpression.new(other)
        end

        def or(other : WhereExpression) : WhereExpression
          OrExpression.new(other)
        end

        def and(other : WhereType)
          AtomExpression.new(other)
        end
      end

      property distincts : String?
      property selects : Array(String)
      property where_expression : WhereExpression = InitialExpression.new
      property joins = [] of Symbol | String
      property preloads = [] of NamedTuple(symbol: Symbol, query: Query?)
      property order_bys = [] of String
      property limit : Int32?
      property offset : Int32?
      property group_bys : String?

      # Adds `DISTINCT` to the query
      #
      # ```
      # Query.distinct("users.name")
      # ```
      def self.distinct(dist : String)
        self.new.distinct(dist)
      end

      # Fields to select, separated by comma.  Default is "*"
      #
      # ```
      # Query.select(["id", "name"])
      # ```
      def self.select(selects : Array(String))
        self.new.select(selects)
      end

      {% for method in %i[where or_where] %}
        # Query.{{ method.id }} with Key => Value pair(s)
        #
        # ```
        # Query.{{ method.id }}(name: "Thor", age: 60)
        # ```
        def self.{{ method.id }}(**wheres)
          self.new.{{ method.id }}(**wheres)
        end

        # Query#{{ method.id }} with Key => Value pair(s)
        #
        # ```
        # query.{{ method.id }}(name: "Thor", age: 60)
        # ```
        def {{ method.id }}(**wheres)
          @where_expression = @where_expression.{{ method.id }}(**wheres)
          self
        end

        # Query.{{ method.id }} with a String and Array(DbValue)
        #
        # ```
        # Query.{{ method.id }}("users.id > ?", [10])
        # ```
        def self.{{ method.id }}(where_string : String, params : Array(DbValue | PkeyValue))
          self.new.{{ method.id }}(where_string, params)
        end

        # Query#{{ method.id }} with a String and Array(DbValue)
        #
        # ```
        # query.{{ method.id }}("users.id > ?", [10])
        # ```
        def {{ method.id }}(where_string : String, params : Array(DbValue))
          @where_expression = @where_expression.{{ method.id }}(where_string, params)
          self
        end

        # Query.{{ method.id }} with a Symbol and DbValue
        #
        # ```
        # Query.{{ method.id }}(:name, "Conan")
        # ```
        def self.{{ method.id }}(where_sym : Symbol, param : DbValue)
          self.new.{{ method.id }}(where_sym, param)
        end

        # Query#{{ method.id }} with a Symbol and DbValue
        #
        # ```
        # query.{{ method.id }}(:name, "Conan")
        # ```
        def {{ method.id }}(where_sym : Symbol, param : DbValue)
          @where_expression = @where_expression.{{ method.id }}(where_sym, param)
          self
        end

        # Query.{{ method.id }} with a Symbol and Array(DbValue)
        #
        # ```
        # Query.{{ method.id }}(:name, ["Conan", "Zeus"])
        # ```
        def self.{{ method.id }}(where_sym : Symbol, params : Array(DbValue | PkeyValue))
          self.new.{{ method.id }}(where_sym, params)
        end

        # Query#{{ method.id }} with a Symbol and Array(DbValue)
        #
        # ```
        # query.{{ method.id }}(:name, ["Conan", "Zeus"])
        # ```
        def {{ method.id }}(where_sym : Symbol, params : Array(DbValue))
          @where_expression = @where_expression.{{ method.id }}(where_sym, params)
          self
        end

        # Query.{{ method.id }} with a String
        #
        # ```
        # Query.{{ method.id }}("name IS NOT NULL")
        # ```
        def self.{{ method.id }}(where_string : String)
          self.new.{{ method.id }}(where_string)
        end

        # Query#{{ method.id }} with a String
        #
        # ```
        # query.{{ method.id }}("name IS NOT NULL")
        # ```
        def {{ method.id }}(where_string : String)
          {{ method.id }}(where_string, Array(String).new)
        end

        # Query.{{ method.id }} with a String and String parameter
        #
        # ```
        # Query.{{ method.id }}("name LIKE ?", "%phyllis%")
        # ```
        def self.{{ method.id }}(where_string : String, param : DbValue | PkeyValue)
          self.new.{{ method.id }}(where_string, param)
        end

        # Query.{{ method.id }} with a String and String parameter
        #
        # ```
        # query.{{ method.id }}("name LIKE ?", "%phyllis%")
        # ```
        def {{ method.id }}(where_string : String, param : DbValue | PkeyValue)
          {{ method.id }}(where_string, [param])
        end
      {% end %}

      # Join query with *join_associations*
      #
      # ```
      # Query.join([:posts, :projects])
      # ```
      def self.join(join_associations : Array(Symbol))
        self.new.join(join_associations)
      end

      # Join query with *join_association*
      #
      # ```
      # Query.join(:posts)
      # ```
      def self.join(join_association : Symbol)
        self.new.join(join_association)
      end

      # Join query with a String
      #
      # ```
      # Query.join("INNER JOIN users ON users.id = posts.user_id")
      # ```
      def self.join(join_string : String)
        self.new.join(join_string)
      end

      # Preload associations
      #
      # ```
      # Query.preload([:posts, :projects])
      # ```
      def self.preload(preload_associations : Array(Symbol))
        self.new.preload(preload_associations)
      end

      # Preload associations, queries the association
      #
      # ```
      # Query.preload([:posts, :projects], Query.where(name: "name"))
      # ```
      def self.preload(preload_associations : Array(Symbol), query : Query)
        self.new.preload(preload_associations, query)
      end

      # Preload associations
      #
      # ```
      # Query.preload(:posts)
      # ```
      def self.preload(preload_association : Symbol)
        self.new.preload(preload_association)
      end

      # Preload associations, queries the association
      #
      # ```
      # Query.preload(:posts, Query.where(name: "name"))
      # ```
      def self.preload(preload_association : Symbol, query : Query)
        self.new.preload(preload_association, query)
      end

      # Field to ORDER BY
      #
      # ```
      # Query.order_by("last_name ASC")
      # ```
      def self.order_by(order : String)
        self.new.order_by(order)
      end

      # Query LIMIT
      #
      # ```
      # Query.limit(50)
      # ```
      def self.limit(lim : Int32 | Int64)
        self.new.limit(lim)
      end

      # Query OFFSET
      #
      # ```
      # Query.offset(20)
      # ```
      def self.offset(off : Int32 | Int64)
        self.new.offset(off)
      end

      # Query GROUP BY
      #
      # ```
      # Query.where(name: "Bill").join(:posts).group_by("users.id")
      # ```
      def self.group_by(gb : String)
        self.new.group_by(gb)
      end

      def initialize
        @selects = ["*"]
      end

      # Combine two queries and returns a new query. Array type properties will be concatenated, however non
      # array type properties will be overridden by the passed "query"
      #
      # ```
      # query = Query.where(name: "user_name")
      # query2 = Query.where(age: 21)
      # query.combine(query2)
      # ```
      def combine(query : Query)
        new_query = self.dup

        {% for prop in ["selects", "joins", "preloads", "order_bys"] %}
          new_query.{{prop.id}} = (new_query.{{prop.id}} + query.{{prop.id}}).uniq
        {% end %}

        new_query.where_expression = AndExpression.new(where_expression, query.where_expression)

        {% for prop in ["distincts", "limit", "offset", "group_bys"] %}
          new_query.{{prop.id}} = query.{{prop.id}}
        {% end %}

        new_query
      end

      # Adds `DISTINCT` to the query
      #
      # ```
      # Query.distinct("users.name")
      # ```
      def distinct(dist : String)
        @distincts = dist
        self
      end

      # Fields to select, separated by comma.  Default is "*"
      #
      # ```
      # Query.select(['id', 'name'])
      # ```
      def select(selects : Array(String))
        @selects = selects
        self
      end

      # Join query with *join_associations*
      #
      # ```
      # Query.join([:posts, :projects])
      # ```
      def join(join_associations : Array(Symbol))
        @joins += join_associations
        self
      end

      # Join query with *join_association*
      #
      # ```
      # Query.join(:posts)
      # ```
      def join(join_association : Symbol)
        @joins.push(join_association)
        self
      end

      # Join query with a String
      #
      # ```
      # q = Query.new
      # q.join("INNER JOIN users ON users.id = posts.user_id")
      # ```
      def join(join_string : String)
        @joins.push(join_string)
        self
      end

      # Preload associations
      #
      # ```
      # Query.preload([:posts, :projects])
      # ```
      def preload(preload_associations : Array(Symbol))
        @preloads += preload_associations.map { |a| {symbol: a, query: nil} }
        self
      end

      # Preload associations, queries the association
      #
      # ```
      # Query.preload([:posts, :projects], Query.where(name: "name"))
      # ```
      def preload(preload_associations : Array(Symbol), query : Query)
        @preloads += preload_associations.map { |a| {symbol: a, query: query} }
        self
      end

      # Preload assoication
      #
      # ```
      # Query.preload(:posts)
      # ```
      def preload(preload_association : Symbol)
        @preloads.push({symbol: preload_association, query: nil})
        self
      end

      # Preload assoication, queries the association
      #
      # ```
      # Query.preload(:posts, Query.where(name: "name"))
      # ```
      def preload(preload_association : Symbol, query : Query)
        @preloads.push({symbol: preload_association, query: query})
        self
      end

      # Field to ORDER BY
      #
      # ```
      # Query.order_by("last_name ASC")
      # ```
      def order_by(order)
        @order_bys.push(order)
        self
      end

      # Query LIMIT
      #
      # ```
      # Query.limit(50)
      # ```
      def limit(lim)
        @limit = lim
        self
      end

      # Query OFFSET
      #
      # ```
      # Query.offset(20)
      # ```
      def offset(off)
        @offset = off
        self
      end

      # Query GROUP BY
      #
      # ```
      # Query.where(name: "Bill").join(:posts).group_by("users.id")
      # ```
      def group_by(gb : String)
        @group_bys = gb
        self
      end

      # Query instance AND
      #
      # Yields a where expression to group wheres or or_wheres together.
      # The block return value must be a where expression which will
      # form an AND expression with the current expression
      #
      # ```
      # Query.where(city: "Los Angeles").and do |e|
      #   e.where(name: "Bill")
      #     .where("age > 20")
      #     .or_where(name: "Wendy")
      # end
      #
      # # => SELECT * FROM users WHERE
      # #    (city = 'Los Angeles') AND (
      # #      (name = 'Bill') AND
      # #      (age  > 20) OR
      # #      (name = 'Wendy')
      # #    )
      # ```
      def and
        @where_expression = @where_expression.and do |expression|
          yield expression
        end
        self
      end

      # Query instance AND with other Query/Queries
      #
      # Combine the where_expression with the one of one or more other Queries using AND
      #
      # ```
      # Query.where(city: "Los Angeles").and(
      #   Query.or_where(name: "Bill", age: 20)
      #   Query.or_where(name: "Wendy", age: 50)
      # )
      #
      # # => SELECT * FROM users WHERE
      # #    (city = 'Los Angeles')
      # #    AND ((name = 'Bill') OR (age = 20))
      # #    AND ((name = 'Wendy') OR (age = 50))
      # ```
      def and(*queries : self)
        @where_expression = queries.reduce(@where_expression) do |result, query|
          result.and(query.where_expression)
        end
        self
      end

      # Query instance OR
      # Yields a where expression to group wheres or or_wheres together.
      # The block return value must be a where expression which will
      # form an OR expression with the current expression
      #
      # ```
      # Query.where(city: "Los Angeles", name: "Bill").or do |e|
      #   e.where("age > 20").or_where(name: "Wendy")
      # end
      #
      # # => SELECT * FROM users WHERE
      # #    (city = 'Los Angeles') AND (name = 'Bill') OR (
      # #      (age  > 20) OR
      # #      (name = 'Wendy')
      # #    )
      # ```
      def or
        @where_expression = @where_expression.or do |expression|
          yield expression
        end
        self
      end

      # Query instance OR with other Query/Queries
      #
      # Combine the where_expression with the one of one or more other Queries using OR
      #
      # ```
      # Query.where(city: "Los Angeles").or(
      #   Query.where(name: "Bill", age: 20)
      #   Query.where(name: "Wendy", age: 50)
      # )
      #
      # # => SELECT * FROM users WHERE
      # #    (city = 'Los Angeles')
      # #    OR ((name = 'Bill') AND (age = 20))
      # #    OR ((name = 'Wendy') AND (age = 50))
      # ```
      def or(*queries : self)
        @where_expression = queries.reduce(@where_expression) do |result, query|
          result.or(query.where_expression)
        end
        self
      end
    end
  end
end
