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
      property joins = [] of Symbol
      property preloads = [] of Symbol
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

      # Key => Value pair(s) used in query `WHERE`
      #
      # ```
      # Query.where(name: "Thor", age: 60)
      # ```
      def self.where(**wheres)
        self.new.where(**wheres)
      end

      # Query WHERe with a string
      #
      # ```
      # Query.where("users.id > ?", [10])
      # ```
      def self.where(where_string : String, params : Array(DbValue | PkeyValue))
        self.new.where(where_string, params)
      end

      # Query WHERe with a Symbol and DbValue
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

      # Key => Value pair(s) used in query `OR WHERE`
      #
      # ```
      # Query.where(name: "Thor", age: 60)
      # ```
      def self.or_where(**or_wheres)
        self.new.or_where(**or_wheres)
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

      # Preload assoications
      #
      # ```
      # Query.preload([:posts, :projects])
      # ```
      def self.preload(preload_associations : Array(Symbol))
        self.new.preload(preload_associations)
      end

      # Preload assoication
      #
      # ```
      # Query.preload(:posts)
      # ```
      def self.preload(preload_association : Symbol)
        self.new.preload(preload_association)
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
        # @selects = Array(String).new
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

      # Query where with a Symbol and DbValue
      #
      # ```
      # Query.where(:name, "Conan")
      # ```
      def where(where_sym : Symbol, param : DbValue)
        @wheres.push(Hash.zip([where_sym], [param]))
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

      # Preload assoications
      #
      # ```
      # Query.preload([:posts, :projects])
      # ```
      def preload(preload_associations : Array(Symbol))
        @preloads += preload_associations
        self
      end

      # Preload assoication
      #
      # ```
      # Query.preload(:posts)
      # ```
      def preload(preload_association : Symbol)
        @preloads.push(preload_association)
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
