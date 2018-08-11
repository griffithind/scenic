
require "acceptance_helper"

describe "User manages views" do
  it "handles simple functions" do
    successfully "rails generate scenic:function get_result"
    write_definition "get_result_v01", <<~SQL
      CREATE FUNCTION get_result()
      RETURNS text AS $$
      select 'needle';
      $$
      LANGUAGE SQL
      IMMUTABLE;
    SQL

    successfully "rake db:migrate"
    verify_result "select get_result() as term", "needle"

    successfully "rails generate scenic:function get_result"
    verify_identical_function_definitions "get_result_v01", "get_result_v02"

    write_definition "get_result_v02", <<~SQL
      CREATE FUNCTION get_result()
      RETURNS text AS $$
      select 'haystack';
      $$
      LANGUAGE SQL
      IMMUTABLE;
    SQL
    successfully "rake db:migrate"

    successfully "rake db:reset"
    verify_result "select get_result() as term", "haystack"

    successfully "rake db:rollback"
    successfully "rake db:rollback"
  end

  def successfully(command)
    `RAILS_ENV=test #{command}`
    expect($?.exitstatus).to eq(0), "'#{command}' was unsuccessful"
  end

  def write_definition(file, contents)
    File.open("db/functions/#{file}.sql", File::WRONLY) do |definition|
      definition.truncate(0)
      definition.write(contents)
    end
  end

  def verify_result(statement, expected_output)
    command = "ActiveRecord::Base.connection.execute(\\\"#{statement}\\\")[0]['term']"
    successfully %{rails runner "#{command} == '#{expected_output}' || exit(1)"}
  end

  def verify_identical_function_definitions(def_a, def_b)
    successfully "cmp db/functions/#{def_a}.sql db/functions/#{def_b}.sql"
  end

  def verify_schema_contains(statement)
    expect(File.readlines("db/schema.rb").grep(/#{statement}/))
      .not_to be_empty, "Schema does not contain '#{statement}'"
  end
end
