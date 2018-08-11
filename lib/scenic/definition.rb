module Scenic
  # @api private
  class Definition
    def initialize(name, version, type)
      @name = name
      @version = version.to_i
      @type = type
    end

    def to_sql
      File.read(full_path).tap do |content|
        if content.empty?
          raise "Define view query in #{path} before migrating."
        end
      end
    end

    def full_path
      Rails.root.join(path)
    end

    def path
      File.join("db", directory_for_type, filename)
    end

    def version
      @version.to_s.rjust(2, "0")
    end

    private

    def directory_for_type
      case @type
      when :view
        "views"
      when :function
        "functions"
      else
        raise "Unknow definition type #{@type}."
      end
    end

    def filename
      "#{@name}_v#{version}.sql"
    end
  end
end
