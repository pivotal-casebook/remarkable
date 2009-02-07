module Remarkable # :nodoc:
  module ActiveRecord # :nodoc:
    module Matchers # :nodoc:
      class ValidateUniquenessOfMatcher < Remarkable::Matcher::Base
        include Remarkable::ActiveRecord::Helpers

        def initialize(*attributes)
          load_options(attributes.extract_options!)
          @attributes = attributes
        end

        def message(message)
          @options[:message] = message
          self
        end

        def scope(scoped)
          @options[:scope] = [*scoped].compact
          self
        end

        # TODO Deprecate this
        #
        def scoped_to(scoped)
          @options[:scope] = [*scoped].compact
          self
        end

        def matches?(subject)
          @subject = subject

          assert_matcher_for(@attributes) do |attribute|
            @attribute = attribute

            find_first_object? &&
            have_attribute? &&
            valid_when_changing_scoped_attribute?
          end
        end

        def description
          "require unique value for #{@attributes.to_sentence}#{" scoped to #{@options[:scope].to_sentence}" unless @options[:scope].blank?}"
        end

        private

        def find_first_object?
          return true if @existing = model_class.find(:first)

          @missing = "Can't find first #{model_class}"
          return false
        end

        def have_attribute?
          @object = model_class.new
          @existing_value = @existing.send(@attribute)

          @options[:scope].each do |s|
            unless @object.respond_to?(:"#{s}=")
              @missing = "#{model_name} doesn't seem to have a #{s} attribute."
              return false
            end
            @object.send("#{s}=", @existing.send(s))
          end

          return true if assert_bad_value(@object, @attribute, @existing_value, @options[:message])

          @missing = "not require unique value for #{@attribute}#{" scoped to #{@options[:scope].join(', ')}" unless @options[:scope].blank?}"
          return false
        end

        # Now test that the object is valid when changing the scoped attribute
        # TODO:  There is a chance that we could change the scoped field
        # to a value that's already taken.  An alternative implementation
        # could actually find all values for scope and create a unique
        # one.
        def valid_when_changing_scoped_attribute?
          @options[:scope].each do |s|
            # Assume the scope is a foreign key if the field is nil
            @object.send("#{s}=", @existing.send(s).nil? ? 1 : @existing.send(s).next)
            unless assert_good_value(@object, @attribute, @existing_value, @options[:message])
              @missing = "#{model_name} is not valid when changing the scoped attribute for #{s}"
              return false
            end
          end
          true
        end

        def load_options(options)
          @options = {
            :message => :taken
          }.merge(options)

          if options[:scoped_to] # TODO Deprecate scoped_to
            @options[:scope] = [*options[:scoped_to]].compact
          else
            @options[:scope] = [*options[:scope]].compact
          end
        end

        def expectation
          "that the #{model_name} cannot be saved if #{@attribute}#{" scoped to #{@options[:scope].to_sentence}" unless @options[:scope].blank?} is not unique"
        end
      end

      # Ensures that the model cannot be saved if one of the attributes listed is not unique.
      # Requires an existing record
      #
      # Options:
      # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
      #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages.taken')</tt>
      # * <tt>:scoped_to</tt> - field(s) to scope the uniqueness to.
      #
      # Examples:
      #   it { should validate_uniqueness_of(:keyword, :username) }
      #   it { should validate_uniqueness_of(:name, :message => "O NOES! SOMEONE STOELED YER NAME!") }
      #   it { should validate_uniqueness_of(:email, :scope => :name) }
      #   it { should validate_uniqueness_of(:address, :scope => [:first_name, :last_name]) }
      #
      def validate_uniqueness_of(*attributes)
        ValidateUniquenessOfMatcher.new(*attributes)
      end
      alias :require_unique_attributes :validate_uniqueness_of
    end
  end
end