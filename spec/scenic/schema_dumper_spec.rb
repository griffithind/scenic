require "spec_helper"

class Search < ActiveRecord::Base; end

class SearchInAHaystack < ActiveRecord::Base
  self.table_name = '"search in a haystack"'
end

describe Scenic::SchemaDumper, :db do
  it "dumps a create_view for a view in the database" do
    view_definition = "SELECT 'needle'::text AS haystack"
    Search.connection.create_view :searches, sql_definition: view_definition
    stream = StringIO.new

    ActiveRecord::SchemaDumper.dump(Search.connection, stream)

    output = stream.string

    expect(output).to include 'create_view "searches", sql_definition: <<-SQL'
    expect(output).to include view_definition

    Search.connection.drop_view :searches

    silence_stream(STDOUT) { eval(output) }

    expect(Search.first.haystack).to eq "needle"
  end


  it "dumps a create_function for a function in the database" do
    function_definition = <<~SQL
      CREATE FUNCTION greetings()
      RETURNS text as $$
      SELECT 'needle';
      $$
      LANGUAGE SQL;
    SQL
    function_statements = "SELECT 'needle';"
    Search.connection.create_function :greetings, sql_definition: function_definition
    stream = StringIO.new

    ActiveRecord::SchemaDumper.dump(Search.connection, stream)

    output = stream.string

    expect(output).to include 'create_function "greetings", sql_definition: <<-SQL'
    expect(output).to include function_statements

    Search.connection.drop_function :greetings

    silence_stream(STDOUT) { eval(output) }
  end

  it "dumps a create_view for a materialized view in the database" do
    view_definition = "SELECT 'needle'::text AS haystack"
    Search.connection.create_view :searches, materialized: true, sql_definition: view_definition
    stream = StringIO.new

    ActiveRecord::SchemaDumper.dump(Search.connection, stream)

    output = stream.string

    expect(output).to include 'create_view "searches", materialized: true, sql_definition: <<-SQL'
    expect(output).to include view_definition
  end

  context "with views in non public schemas" do
    it "dumps a create_view including namespace for a view in the database" do
      view_definition = "SELECT 'needle'::text AS haystack"
      Search.connection.execute "CREATE SCHEMA scenic; SET search_path TO scenic, public"
      Search.connection.create_view :"scenic.searches", sql_definition: view_definition
      stream = StringIO.new

      ActiveRecord::SchemaDumper.dump(Search.connection, stream)

      output = stream.string
      expect(output).to include 'create_view "scenic.searches",'

      Search.connection.drop_view :'scenic.searches'
    end
  end

  it "ignores tables internal to Rails" do
    view_definition = "SELECT 'needle'::text AS haystack"
    Search.connection.create_view :searches, sql_definition: view_definition
    stream = StringIO.new

    ActiveRecord::SchemaDumper.dump(Search.connection, stream)

    output = stream.string

    expect(output).to include 'create_view "searches"'
    expect(output).not_to include "ar_internal_metadata"
    expect(output).not_to include "schema_migrations"
  end

  context "with views using unexpected characters in name" do
    it "dumps a create_view for a view in the database" do
      view_definition = "SELECT 'needle'::text AS haystack"
      Search.connection.create_view '"search in a haystack"', sql_definition: view_definition
      stream = StringIO.new

      ActiveRecord::SchemaDumper.dump(Search.connection, stream)

      output = stream.string
      expect(output).to include 'create_view "\"search in a haystack\"",'
      expect(output).to include view_definition

      Search.connection.drop_view :'"search in a haystack"'

      silence_stream(STDOUT) { eval(output) }

      expect(SearchInAHaystack.take.haystack).to eq "needle"
    end
  end

  context "with views using unexpected characters, name including namespace" do
    it "dumps a create_view for a view in the database" do
      view_definition = "SELECT 'needle'::text AS haystack"
      Search.connection.execute(
        "CREATE SCHEMA scenic; SET search_path TO scenic, public")
      Search.connection.create_view 'scenic."search in a haystack"',
        sql_definition: view_definition
      stream = StringIO.new

      ActiveRecord::SchemaDumper.dump(Search.connection, stream)

      output = stream.string
      expect(output).to include 'create_view "scenic.\"search in a haystack\"",'
      expect(output).to include view_definition

      Search.connection.drop_view :'scenic."search in a haystack"'

      silence_stream(STDOUT) { eval(output) }

      expect(SearchInAHaystack.take.haystack).to eq "needle"
    end
  end
end
