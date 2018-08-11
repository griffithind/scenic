require "spec_helper"

describe "Reverting scenic schema function statements", :db do
  around do |example|
    function_sql = <<~SQL
      CREATE FUNCTION greetings()
      RETURNS text as $$
      SELECT 'hola';
      $$
      LANGUAGE SQL;
    SQL
    with_function_definition :greetings, 1, function_sql do
      example.run
    end
  end

  it "reverts dropped view to specified version" do
    run_migration(migration_for_create, :up)
    run_migration(migration_for_drop, :up)
    run_migration(migration_for_drop, :down)

    expect { execute("SELECT greetings() as greeting") }
      .not_to raise_error
  end

  it "reverts updated view to specified version" do
    function_v2_sql = <<~SQL
      CREATE FUNCTION greetings()
      RETURNS text as $$
      SELECT 'good day';
      $$
      LANGUAGE SQL;
    SQL
    with_function_definition :greetings, 2, function_v2_sql do
      run_migration(migration_for_create, :up)
      run_migration(migration_for_update, :up)
      run_migration(migration_for_update, :down)

      greeting = execute("SELECT greetings() as greeting")[0]["greeting"]

      expect(greeting).to eq "hola"
    end
  end

  def migration_for_create
    Class.new(migration_class) do
      def change
        create_function :greetings
      end
    end
  end

  def migration_for_drop
    Class.new(migration_class) do
      def change
        drop_function :greetings, revert_to_version: 1
      end
    end
  end

  def migration_for_update
    Class.new(migration_class) do
      def change
        update_function :greetings, version: 2, revert_to_version: 1
      end
    end
  end

  def migration_class
    if Rails::VERSION::MAJOR >= 5
      ::ActiveRecord::Migration[5.0]
    else
      ::ActiveRecord::Migration
    end
  end

  def run_migration(migration, directions)
    silence_stream(STDOUT) do
      Array.wrap(directions).each do |direction|
        migration.migrate(direction)
      end
    end
  end

  def execute(sql)
    ActiveRecord::Base.connection.execute(sql)
  end
end
