require "spec_helper"

module Scenic
  module Adapters
    describe Postgres::Functions, :db do
      it "returns scenic functions objects for plain old functions" do
        connection = ActiveRecord::Base.connection
        connection.execute <<-SQL
          CREATE FUNCTION get_test()
          RETURNS text AS $$
          SELECT 'Elliot';
          $$
          LANGUAGE SQL;
        SQL

        functions = Postgres::Functions.new(connection).all
        first     = functions.first

        expect(functions.size).to eq 1
        expect(first.name).to eq "get_test"
        expect(first.definition).to include "SELECT 'Elliot';"
      end
    end
  end
end
