require "scenic/version"
require "scenic/railtie"
require "scenic/active_record/command_recorder"
require "scenic/active_record/schema_dumper"
require "scenic/active_record/statements"

module Scenic
  def self.load
    ::ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
      include Scenic::ActiveRecord::Statements
    end

    ::ActiveRecord::Migration::CommandRecorder.class_eval do
      include Scenic::ActiveRecord::CommandRecorder
    end

    ::ActiveRecord::SchemaDumper.class_eval do
      include Scenic::ActiveRecord::SchemaDumper
    end
  end
end
