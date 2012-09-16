require 'pathname'
require 'shellwords'
require 'tilt'
require 'yaml'

class Ruhoh
  # custom, heavily stripped-down implementation of Sprockets::DirectiveProcesser
  # https://github.com/sstephenson/sprockets/blob/master/lib/sprockets/directive_processor.rb
  class SprocketsProcessor < Tilt::Template
    self.default_mime_type = 'text/css'
    attr_reader :pathname, :body

    def prepare
      @pathname = Pathname.new(file)

      # this is the JSON manifest file.
      if data[0] == "{"
        @directives = JSON.parse(data)
        @body = "\n"
      else
        # This is a regular CSS file which we don't want to process
        @body = data
        # Ensure body ends in a new line
        @body  += "\n" if @body != "" && @body !~ /\n\Z/m
      end
    end

    # Implemented for Tilt#render.
    #
    # `context` is a `Context` instance with methods that allow you to
    # access the environment and append to the bundle. See `Context`
    # for the complete API.
    def evaluate(context, locals, &block)
      # regular CSS files should pass through, no directives should exist.
      return @body unless @directives

      @context = context
      @directives.each do |key, value|
        value.each do |path|
          if path.gsub!(/\/\*\*\/\*$/, '') # path/**/*
            process_require_tree_directive(path)
          elsif path.gsub!(/\/\*$/, '') # path/*
            process_require_directory_directive(path)
          else
            process_require_directive(path)
          end
        end
      end
      
      "" # manifest should not be included
    end

    protected
      attr_reader :context

      # The `require` directive functions similar to Ruby's own `require`.
      # It provides a way to declare a dependency on a file in your path
      # and ensures its only loaded once before the source file.
      #
      # `require` works with files in the environment path:
      #
      #     //= require "foo.js"
      #
      # Extensions are optional. If your source file is ".js", it
      # assumes you are requiring another ".js".
      #
      #     //= require "foo"
      #
      # Relative paths work too. Use a leading `./` to denote a relative
      # path:
      #
      #     //= require "./bar"
      #
      def process_require_directive(path)
        context.require_asset(path)
      end

      # `require_directory` requires all the files inside a single
      # directory. It's similar to `path/*` since it does not follow
      # nested directories.
      #
      #     //= require_directory "./javascripts"
      #
      def process_require_directory_directive(path = ".")
        if relative?(path)
          root = pathname.dirname.join(path).expand_path

          unless (stats = stat(root)) && stats.directory?
            raise ArgumentError, "require_directory argument must be a directory"
          end

          context.depend_on(root)

          entries(root).each do |pathname|
            pathname = root.join(pathname)
            if pathname.to_s == self.file
              next
            elsif context.asset_requirable?(pathname)
              context.require_asset(pathname)
            end
          end
        else
          # The path must be relative and start with a `./`.
          raise ArgumentError, "require_directory argument must be a relative path"
        end
      end

      # `require_tree` requires all the nested files in a directory.
      # Its glob equivalent is `path/**/*`.
      #
      #     //= require_tree "./public"
      #
      def process_require_tree_directive(path = ".")
        if relative?(path)
          root = pathname.dirname.join(path).expand_path

          unless (stats = stat(root)) && stats.directory?
            raise ArgumentError, "require_tree argument must be a directory"
          end

          context.depend_on(root)

          each_entry(root) do |pathname|
            if pathname.to_s == self.file
              next
            elsif stat(pathname).directory?
              context.depend_on(pathname)
            elsif context.asset_requirable?(pathname)
              context.require_asset(pathname)
            end
          end
        else
          # The path must be relative and start with a `./`.
          raise ArgumentError, "require_tree argument must be a relative path"
        end
      end

    private
      def relative?(path)
        path =~ /^\.($|\.?\/)/
      end

      def stat(path)
        context.environment.stat(path)
      end

      def entries(path)
        context.environment.entries(path)
      end

      def each_entry(root, &block)
        context.environment.each_entry(root, &block)
      end
  end
end
