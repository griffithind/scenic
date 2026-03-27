module Scenic
  module Adapters
    class Postgres
      # Fetches defined functions from the postgres connection.
      # @api private
      class Functions
        def initialize(connection)
          @connection = connection
        end

        # All of the functions that this connection has defined, sorted
        # according to dependencies between the functions to facilitate
        # dumping and loading.
        #
        # @return [Array<Scenic::Function>]
        def all
          scenic_functions = functions_from_postgres.map(&method(:to_scenic_function))
          sort(scenic_functions)
        end

        private

        attr_reader :connection

        def sort(scenic_functions)
          scenic_function_names = scenic_functions.map(&:name)

          tsorted_functions(scenic_function_names).map do |function_name|
            scenic_functions.find do |sf|
              sf.name == function_name || sf.name == function_name.split(".").last
            end
          end.compact
        end

        # When dumping the functions, their order must be topologically
        # sorted to take into account dependencies
        def tsorted_functions(function_names)
          functions_hash = TSortableHash.new

          ::Scenic.database.execute(DEPENDENT_SQL).each do |relation|
            source = [
              relation["source_schema"],
              relation["source_function"]
            ].compact.join(".")

            dependent = [
              relation["dependent_schema"],
              relation["dependent_function"]
            ].compact.join(".")

            functions_hash[dependent] ||= []
            functions_hash[source] ||= []
            functions_hash[dependent] << source

            function_names.delete(relation["source_function"])
            function_names.delete(relation["dependent_function"])
          end

          # after dependencies, there might be some functions left
          # that don't have any dependencies
          function_names.sort.each { |f| functions_hash[f] ||= [] }
          functions_hash.tsort
        end

        # Query for the dependencies between functions
        DEPENDENT_SQL = <<~SQL.freeze
          SELECT DISTINCT
            source_ns.nspname AS source_schema,
            source_proc.proname AS source_function,
            dependent_ns.nspname AS dependent_schema,
            dependent_proc.proname AS dependent_function
          FROM pg_depend
          JOIN pg_proc AS dependent_proc ON pg_depend.objid = dependent_proc.oid
          JOIN pg_proc AS source_proc ON pg_depend.refobjid = source_proc.oid
          JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_proc.pronamespace
          JOIN pg_namespace source_ns ON source_ns.oid = source_proc.pronamespace
          JOIN pg_language dependent_lang ON dependent_proc.prolang = dependent_lang.oid
          JOIN pg_language source_lang ON source_proc.prolang = source_lang.oid
          WHERE dependent_ns.nspname = ANY (current_schemas(false))
            AND source_ns.nspname = ANY (current_schemas(false))
            AND source_proc.proname != dependent_proc.proname
            AND dependent_lang.lanname IN ('sql', 'plpgsql')
            AND source_lang.lanname IN ('sql', 'plpgsql')
          ORDER BY dependent_proc.proname
        SQL
        private_constant :DEPENDENT_SQL

        class TSortableHash < Hash
          include TSort

          alias_method :tsort_each_node, :each_key
          def tsort_each_child(node, &)
            fetch(node).each(&)
          end
        end
        private_constant :TSortableHash

        def functions_from_postgres
          connection.execute(<<-SQL)
            SELECT
              pp.proname as functionname,
              pn.nspname as namespace,
              pg_get_functiondef(pp.oid) as definition
            FROM pg_proc pp
              LEFT JOIN pg_depend pd ON pp.oid = pd.objid AND 'e' = pd.deptype
              LEFT JOIN pg_namespace pn ON pp.pronamespace = pn.oid
              LEFT JOIN pg_language pl ON pp.prolang = pl.oid
            WHERE
              pl.lanname IN ('sql','plpgsql')
              AND pn.nspname = ANY (current_schemas(false))
              AND pd.objid IS NULL
            ORDER BY pn.nspname, pp.proname
          SQL
        end

        def to_scenic_function(result)
          namespace, functionname = result.values_at "namespace", "functionname"

          namespaced_functionname = if namespace != "public"
            "#{pg_identifier(namespace)}.#{pg_identifier(functionname)}"
          else
            pg_identifier(functionname)
          end

          Scenic::Function.new(
            name: namespaced_functionname,
            definition: result["definition"].strip
          )
        end

        def pg_identifier(name)
          return name if /^[a-zA-Z_][a-zA-Z0-9_]*$/.match?(name)
          pgconn.quote_ident(name)
        end

        def pgconn
          if defined?(PG::Connection)
            PG::Connection
          else
            PGconn
          end
        end
      end
    end
  end
end
