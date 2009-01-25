module DataMapper
  class Query
    class Path
      include Extlib::Assertions

      # silence Object deprecation warnings
      [ :id, :type ].each { |m| undef_method m if method_defined?(m) }

      attr_reader :relationships
      attr_reader :model
      attr_reader :property
      attr_reader :operator

      %w[ gt gte lt lte not eql like in ].each do |sym|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{sym}
            #{"warn \"explicit use of '#{sym}' operator is deprecated\"" if sym == :eql || sym == :in}
            Operator.new(self, :#{sym})
          end
        RUBY
      end

      # duck type the DM::Query::Path to act like a DM::Property
      def field(*args)
        @property ? @property.field(*args) : nil
      end

      # more duck typing
      def to_sym
        @property ? @property.name.to_sym : @model.storage_name(@repository_name).to_sym
      end

      private

      def initialize(repository, relationships, model, property_name = nil)
        assert_kind_of 'repository',    repository,    Repository
        assert_kind_of 'relationships', relationships, Array
        assert_kind_of 'model',         model,         Model
        assert_kind_of 'property_name', property_name, Symbol, NilClass

        @repository_name = repository.name
        @relationships   = relationships
        @model           = model
        @property        = @model.properties(@repository_name)[property_name] if property_name
      end

      def method_missing(method, *args)
        if relationship = @model.relationships(@repository_name)[method]
          repository = DataMapper.repository(@repository_name)
          klass      = klass = model == relationship.child_model ? relationship.parent_model : relationship.child_model
          return Query::Path.new(repository, @relationships.dup << relationship, klass)
        end

        if @model.properties(@repository_name)[method] && @property.nil?
          @property = @model.properties(@repository_name)[method]
          return self
        end

        raise NoMethodError, "undefined property or association '#{method}' on #{@model}"
      end
    end # class Path
  end # class Query
end # module DataMapper
