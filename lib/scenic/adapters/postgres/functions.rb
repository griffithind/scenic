module Scenic
  module Adapters
    class Postgres
      # Fetches defined views from the postgres connection.
      # @api private
      class Functions
        def initialize(connection)
          @connection = connection
        end

        # All of the functionss that this connection has defined.
        #
        # @return [Array<Scenic::Function>]
        def all
          functions_from_postgres.map(&method(:to_scenic_function))
        end

        private

        attr_reader :connection

        def functions_from_postgres
          connection.execute(<<-SQL)
            SELECT
              pp.proname as functionname,
              pn.nspname as namespace,
              pg_get_functiondef(pp.oid) as definition
            FROM pg_proc pp
              LEFT JOIN pg_namespace pn ON pp.pronamespace = pn.oid
              LEFT JOIN pg_language pl ON pp.prolang = pl.oid
            WHERE
              pl.lanname IN ('sql','plpgsql')
              AND pn.nspname NOT LIKE 'pg_%'
              AND pn.nspname <> 'information_schema'
          SQL
        end

        def to_scenic_function(result)
          namespace, functionname = result.values_at "namespace", "functionname"

          if namespace != "public"
            namespaced_functionname =
              "#{pg_identifier(namespace)}.#{pg_identifier(functionname)}"
          else
            namespaced_functionname = pg_identifier(functionname)
          end

          Scenic::Function.new(
            name: namespaced_funtionname,
            definition: result["definition"].strip,
          )
        end

        def pg_identifier(name)
          return name if name =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
          PGconn.quote_ident(name)
        end
      end
    end
  end
end
