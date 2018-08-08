module Crecto
  module Repo
    # Queries are used to retrieve and manipulate data from a repository.  Syntax is much like that of ActiveRecord:
    #
    # `Query.select('id').where(name: "fred").join(:posts).order_by("users.name").limit(1).offset(4)`
    #
    class Query
      property distincts : String?
      property selects : Array(String)
      property wheres = [] of WhereType
      property or_wheres = [] of WhereType
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
      def self.distinct(dist : String)2
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

      # Key => Value pair(s) used in query `WHERE`
      #
      # ```
      # Query.where(name: "Thor", age: 60)
      # ```
      def self.where(**wheres)
        self.new.where(**wheres)
      end

      # Query WHERE with a string
      #
      # ```
      # Query.where("users.id > ?", [10])
      # ```
      def self.where(where_string : String, params : Array(DbValue | PkeyValue))
        self.new.where(where_string, params)
      end

      # Query WHERE with a Symbol and DbValue
      #
      # ```
      # Query.where(:name, "Conan")
      # ```
      def self.where(where_sym : Symbol, param : DbValue)
        self.new.where(where_sym, param)
      end

      # Query WHERE IN with a Symbol and Array(DbValue)
      #
      # ```
      # Query.where(:name, ["Conan", "Zeus"])
      # ```
      def self.where(where_sym : Symbol, params : Array(DbValue | PkeyValue))
        self.new.where(where_sym, params)
      end

      # Query WHERE with a String
      #
      # ```
      # Query.where("name IS NOT NULL")
      # ```
      def self.where(where_string : String)
        self.new.where(where_string)
      end

      # Query WHERE with a String and String parameter
      #
      # ```
      # Query.where("name LIKE ?", "%phyllis%")
      # ```
      def self.where(where_string : String, param : DbValue | PkeyValue)
        self.new.where(where_string, param)
      end

      # Key => Value pair(s) used in query `OR WHERE`
      #
      # ```
      # Query.where(name: "Thor", age: 60)
      # ```
      def self.or_where(**or_wheres)
        self.new.or_where(**or_wheres)
      end

      # Query `OR WHERE` with a String
      # ```
      # Query.or_where("name IS NOT NULL")
      # ```
      def self.or_where(or_where_string : String)
        self.new.or_where(or_where_string)
      end

      # Query `OR WHERE` with a String and String parameter
      #
      # ```
      # Query.or_where("name LIKE ?", "%phyllis%")
      # ```
      def self.or_where(or_where_string : String, param : DbValue | PkeyValue)
        self.new.or_where(or_where_string, param)
      end

      # Query `OR WHERE` with a string and array
      #
      # ```
      # Query.or_where("users.id > ?", [10])
      # ```
      def self.or_where(or_where_string : String, params : Array(DbValue | PkeyValue))
        self.new.or_where(or_where_string, params)
      end

      # Query `OR WHERE` with a Symbol and DbValue
      #
      # ```
      # Query.or_where(:name, "Conan")
      # ```
      def self.or_where(or_where_sym : Symbol, param : DbValue)
        self.new.or_where(or_where_sym, param)
      end

      # Query `OR WHERE` with a Symbol and Array(DbValue)
      #
      # ```
      # Query.or_where(:name, ["Conan", "Zeus"])
      # ```
      def self.or_where(or_where_sym : Symbol, params : Array(DbValue | PkeyValue))
        self.new.or_where(or_where_sym, params)
      end

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

        {% for prop in ["selects", "wheres", "or_wheres", "joins", "preloads", "order_bys"] %}
          new_query.{{prop.id}} = (new_query.{{prop.id}} + query.{{prop.id}}).uniq
        {% end %}

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

      # Key => Value pair(s) used in query `WHERE`
      #
      # ```
      # Query.where(name: "Thor", age: 60)
      # ```
      def where(**wheres)
        wheres = wheres.to_h
        @wheres.push(Hash.zip(wheres.keys, wheres.values))
        self
      end

      # Query where with a string
      #
      # ```
      # Query.where("users.id > ?", [10])
      # ```
      def where(where_string : String, params : Array(DbValue))
        @wheres.push({clause: where_string, params: params.map { |p| p.as(DbValue) }})
        self
      end

      # Query WHERE with a Symbol and DbValue
      #
      # ```
      # Query.where(:name, "Conan")
      # ```
      def where(where_sym : Symbol, param : DbValue)
        @wheres.push({where_sym => param.as(DbValue)})
        self
      end

      # Query WHERE IN with a Symbol and Array(DbValue)
      #
      # ```
      # Query.where(:name, ["Conan", "Zeus"])
      # ```
      def where(where_sym : Symbol, params : Array(DbValue))
        w = {} of Symbol => Array(DbValue)
        w[where_sym] = params.map { |x| x.as(DbValue) }
        @wheres.push(w)
        self
      end

      # Query WHERE with a String
      #
      # ```
      # Query.where("name IS NOT NULL")
      # ```
      def where(where_string : String)
        where(where_string, Array(String).new)
      end

      # Query WHERE with a String and String parameter
      #
      # ```
      # Query.where("name LIKE ?", "%phyllis%")
      # ```
      def where(where_string : String, param : DbValue | PkeyValue)
        where(where_string, [param])
      end

      # Key => Value pair(s) used in query `OR WHERE`
      #
      # ```
      # Query.where(name: "Thor", age: 60)
      # ```
      def or_where(**or_wheres)
        or_wheres = or_wheres.to_h
        @or_wheres.push or_wheres
        self
      end

      # Query or_where with a string
      #
      # ```
      # Query.or_where("users.id > ?", [10])
      # ```
      def or_where(or_where_string : String, params : Array(DbValue))
        @or_wheres.push({clause: or_where_string, params: params.map { |p| p.as(DbValue) }})
        self
      end

      # Query OR_WHERE with a Symbol and DbValue
      #
      # ```
      # Query.or_where(:name, "Conan")
      # ```
      def or_where(or_where_sym : Symbol, param : DbValue)
        @or_wheres.push({or_where_sym => param.as(DbValue)})
        self
      end

      # Query OR_WHERE IN with a Symbol and Array(DbValue)
      #
      # ```
      # Query.or_where(:name, ["Conan", "Zeus"])
      # ```
      def or_where(or_where_sym : Symbol, params : Array(DbValue))
        w = {} of Symbol => Array(DbValue)
        w[or_where_sym] = params.map { |x| x.as(DbValue) }
        @or_wheres.push(w)
        self
      end

      # Query OR_WHERE with a String
      #
      # ```
      # Query.or_where("name IS NOT NULL")
      # ```
      def or_where(or_where_string : String)
        or_where(or_where_string, Array(String).new)
      end

      # Query OR_WHERE with a String and String parameter
      #
      # ```
      # Query.or_where("name LIKE ?", "%phyllis%")
      # ```
      def or_where(or_where_string : String, param : DbValue | PkeyValue)
        or_where(or_where_string, [param])
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
        @preloads += preload_associations.map{|a| {symbol: a, query: nil}}
        self
      end

      # Preload associations, queries the association
      #
      # ```
      # Query.preload([:posts, :projects], Query.where(name: "name"))
      # ```
      def preload(preload_associations : Array(Symbol), query : Query)
        @preloads += preload_associations.map{|a| {symbol: a, query: query}}
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
    end
  end
end
