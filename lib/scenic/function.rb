module Scenic
  # The in-memory representation of a function definition.
  #
  # **This object is used internally by adapters and the schema dumper and is
  # not intended to be used by application code. It is documented here for
  # use by adapter gems.**
  #
  # @api extension
  class Function
    # The name of the function.
    # @return [String]
    attr_reader :name

    # The function definition.
    # @return [String]
    attr_reader :definition

    # Returns a new instance of Function.
    #
    # @param name [String] The name of the function.
    # @param definition [String] The definition of the function.
    def initialize(name:, definition:)
      @name = name
      @definition = definition
    end

    # @api private
    def ==(other)
      name == other.name &&
        definition == other.definition
    end

    # @api private
    def to_schema
      <<-DEFINITION
  create_function #{name.inspect}, sql_definition: <<-\SQL
    #{definition.indent(2)}
  SQL
      DEFINITION
    end
  end
end
