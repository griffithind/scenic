require "spec_helper"

module Scenic
  module Adapters
    describe Postgres, :db do
      describe "#create_view" do
        it "successfully creates a view" do
          adapter = Postgres.new

          adapter.create_view("greetings", "SELECT text 'hi' AS greeting")

          expect(adapter.views.map(&:name)).to include("greetings")
        end
      end

      describe "#create_materialized_view" do
        it "successfully creates a materialized view" do
          adapter = Postgres.new

          adapter.create_materialized_view(
            "greetings",
            "SELECT text 'hi' AS greeting",
          )

          view = adapter.views.first
          expect(view.name).to eq("greetings")
          expect(view.materialized).to eq true
        end

        it "handles semicolon in definition when using `with no data`" do
          adapter = Postgres.new

          adapter.create_materialized_view(
            "greetings",
            "SELECT text 'hi' AS greeting; \n",
            no_data: true,
          )

          view = adapter.views.first
          expect(view.name).to eq("greetings")
          expect(view.materialized).to eq true
        end

        it "raises an exception if the version of PostgreSQL is too old" do
          connection = double("Connection", supports_materialized_views?: false)
          connectable = double("Connectable", connection: connection)
          adapter = Postgres.new(connectable)
          err = Scenic::Adapters::Postgres::MaterializedViewsNotSupportedError

          expect { adapter.create_materialized_view("greetings", "select 1") }
            .to raise_error err
        end
      end

      describe "#create_function" do
        it "successfully creates a function" do
          adapter = Postgres.new

          function_definition = <<~SQL
          CREATE FUNCTION greetings()
          RETURNS text as $$
          SELECT text 'hi';
          $$
          LANGUAGE sql;
          SQL

          adapter.create_function("greetings", function_definition)
          expect(adapter.functions.map(&:name)).to include("greetings")
        end
      end

      describe "#replace_view" do
        it "successfully replaces a view" do
          adapter = Postgres.new

          adapter.create_view("greetings", "SELECT text 'hi' AS greeting")

          view = adapter.views.first.definition
          expect(view).to eql "SELECT 'hi'::text AS greeting;"

          adapter.replace_view("greetings", "SELECT text 'hello' AS greeting")

          view = adapter.views.first.definition
          expect(view).to eql "SELECT 'hello'::text AS greeting;"
        end
      end

      describe "#drop_view" do
        it "successfully drops a view" do
          adapter = Postgres.new

          adapter.create_view("greetings", "SELECT text 'hi' AS greeting")
          adapter.drop_view("greetings")

          expect(adapter.views.map(&:name)).not_to include("greetings")
        end
      end

      describe "#drop_materialized_view" do
        it "successfully drops a materialized view" do
          adapter = Postgres.new

          adapter.create_materialized_view(
            "greetings",
            "SELECT text 'hi' AS greeting",
          )
          adapter.drop_materialized_view("greetings")

          expect(adapter.views.map(&:name)).not_to include("greetings")
        end

        it "raises an exception if the version of PostgreSQL is too old" do
          connection = double("Connection", supports_materialized_views?: false)
          connectable = double("Connectable", connection: connection)
          adapter = Postgres.new(connectable)
          err = Scenic::Adapters::Postgres::MaterializedViewsNotSupportedError

          expect { adapter.drop_materialized_view("greetings") }
            .to raise_error err
        end
      end

      describe "#drop_function" do
        it "successfully drops a function" do
          adapter = Postgres.new

          function_definition = <<~SQL
          CREATE FUNCTION greetings()
          RETURNS text as $$
          SELECT text 'hi';
          $$
          LANGUAGE sql;
          SQL

          adapter.create_function("greetings", function_definition)
          adapter.drop_function("greetings")

          expect(adapter.functions.map(&:name)).not_to include("greetings")
        end
      end

      describe "#refresh_materialized_view" do
        it "raises an exception if the version of PostgreSQL is too old" do
          connection = double("Connection", supports_materialized_views?: false)
          connectable = double("Connectable", connection: connection)
          adapter = Postgres.new(connectable)
          err = Scenic::Adapters::Postgres::MaterializedViewsNotSupportedError

          expect { adapter.refresh_materialized_view(:tests) }
            .to raise_error err
        end

        it "can refresh the views dependencies first" do
          connection = double("Connection").as_null_object
          connectable = double("Connectable", connection: connection)
          adapter = Postgres.new(connectable)
          expect(Scenic::Adapters::Postgres::RefreshDependencies)
            .to receive(:call).with(:tests, adapter, connection)
          adapter.refresh_materialized_view(:tests, cascade: true)
        end

        context "refreshing concurrently" do
          it "raises descriptive error if concurrent refresh is not possible" do
            adapter = Postgres.new
            adapter.create_materialized_view(:tests, "SELECT text 'hi' as text")

            expect {
              adapter.refresh_materialized_view(:tests, concurrently: true)
            }.to raise_error(/Create a unique index with no WHERE clause/)
          end

          it "raises an exception if the version of PostgreSQL is too old" do
            connection = double("Connection", postgresql_version: 90300)
            connectable = double("Connectable", connection: connection)
            adapter = Postgres.new(connectable)
            e = Scenic::Adapters::Postgres::ConcurrentRefreshesNotSupportedError

            expect {
              adapter.refresh_materialized_view(:tests, concurrently: true)
            }.to raise_error e
          end
        end
      end

      describe "#views" do
        it "returns the views defined on this connection" do
          adapter = Postgres.new

          ActiveRecord::Base.connection.execute <<-SQL
            CREATE VIEW parents AS SELECT text 'Joe' AS name
          SQL

          ActiveRecord::Base.connection.execute <<-SQL
            CREATE VIEW children AS SELECT text 'Owen' AS name
          SQL

          ActiveRecord::Base.connection.execute <<-SQL
            CREATE MATERIALIZED VIEW people AS
            SELECT name FROM parents UNION SELECT name FROM children
          SQL

          ActiveRecord::Base.connection.execute <<-SQL
            CREATE VIEW people_with_names AS
            SELECT name FROM people
            WHERE name IS NOT NULL
          SQL

          expect(adapter.views.map(&:name)).to eq [
            "parents",
            "children",
            "people",
            "people_with_names",
          ]
        end

        context "with views in non public schemas" do
          it "returns also the non public views" do
            adapter = Postgres.new

            ActiveRecord::Base.connection.execute <<-SQL
              CREATE VIEW parents AS SELECT text 'Joe' AS name
            SQL

            ActiveRecord::Base.connection.execute <<-SQL
              CREATE SCHEMA scenic;
              CREATE VIEW scenic.parents AS SELECT text 'Maarten' AS name;
              SET search_path TO scenic, public;
            SQL

            expect(adapter.views.map(&:name)).to eq [
              "parents",
              "scenic.parents",
            ]
          end
        end
      end

      describe "#functions" do
        it "returns the functions defined on this connection" do
          adapter = Postgres.new

          ActiveRecord::Base.connection.execute <<-SQL
          CREATE FUNCTION get_parent()
          RETURNS text as $$
          SELECT text 'joe';
          $$
          LANGUAGE sql;
          SQL

          ActiveRecord::Base.connection.execute <<-SQL
          CREATE FUNCTION get_child()
          RETURNS text as $$
          SELECT text 'Owen';
          $$
          LANGUAGE sql;
          SQL

          expect(adapter.functions.map(&:name)).to eq [
            "get_parent",
            "get_child",
          ]
        end

        context "with functions in non public schemas" do
          it "returns also the non public functions" do
            adapter = Postgres.new

            ActiveRecord::Base.connection.execute <<-SQL
              CREATE FUNCTION get_parent()
              RETURNS text as $$
              SELECT text 'joe';
              $$
              LANGUAGE sql;
            SQL

            ActiveRecord::Base.connection.execute <<-SQL
              CREATE SCHEMA scenic;
              CREATE FUNCTION scenic.get_parent()
              RETURNS text as $$
              SELECT text 'joe';
              $$
              LANGUAGE sql;
              SET search_path TO scenic, public;
            SQL

            expect(adapter.functions.map(&:name)).to eq [
              "get_parent",
              "scenic.get_parent",
            ]
          end
        end
      end
    end
  end
end
