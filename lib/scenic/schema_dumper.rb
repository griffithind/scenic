require "rails"
require_relative "function"
module Scenic
  # @api private
  module SchemaDumper
    def tables(stream)
      super
      views(stream)
      functions(stream)
    end

    def views(stream)
      dumpable_views_in_database = Scenic.database.views.reject do |view|
        ignored?(view.name)
      end

      if dumpable_views_in_database.any?
        stream.puts
      end

      dumpable_views_in_database.each do |view|
        stream.puts(view.to_schema)
        indexes(view.name, stream)
      end
    end

    def functions(stream)
      dumpable_functions_in_database.each do |function|
        stream.puts(function.to_schema)
      end
    end

    private

    def dumpable_functions_in_database
      @dumpable_functions_in_database ||= Scenic.database.functions
    end
  end
end
