require "spec_helper"
require "generators/scenic/function/function_generator"

describe Scenic::Generators::FunctionGenerator, :generator do
  it "creates function definition and migration files" do
    migration = file("db/migrate/create_get_users.rb")
    function_definition = file("db/functions/get_users_v01.sql")

    run_generator ["get_users"]

    expect(migration).to be_a_migration
    expect(function_definition).to exist
  end

  it "updates an existing function" do
    with_function_definition("get_users", 1, "hello") do
      migration = file("db/migrate/update_get_users_to_version_2.rb")
      function_definition = file("db/functions/get_users_v02.sql")
      allow(Dir).to receive(:entries).and_return(["get_users_v01.sql"])

      run_generator ["get_users"]

      expect(migration).to be_a_migration
      expect(function_definition).to exist
    end
  end

  context "for functions created in a schema other than 'public'" do
    it "creates function definition and migration files" do
      migration = file("db/migrate/create_non_public_get_users.rb")
      function_definition = file("db/functions/non_public_get_users_v01.sql")

      run_generator ["non_public.get_users"]

      expect(migration).to be_a_migration
      expect(function_definition).to exist
    end
  end
end
