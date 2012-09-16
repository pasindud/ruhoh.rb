require 'sprockets'
require 'ruhoh/compilers/sprockets/sprockets_processor'

class Ruhoh
  module Compiler
    module SprocketsCompiler
      
      # Hack Sprockets.
      # Sprockets works by parsing "require directives" in a <filename>.css file (bundled-asset).
      # You can only give sprockets a valid bundled-asset file and parse its dependencies _into_ that file.
      # We want theme_config to act as the dependency graph for a
      # not-yet-created bundled-asset.
      #
      # How we do it:
      #  1. Parse theme_config and group by bundled-asset -> dependency directives.
      #     One bundled-asset should exist for each layout specified.
      #  2. Create bundled-asset and place JSON dependency graph inside.
      #     Note the file will be named <filename>.css but will contain JSON
      #     Sprockets compares mime-type for all parents<->dependencies so it needs to be .css
      #
      #  3. Replace Sprockets::DirectiveProcessor with one that can parse
      #     JSON and turn it into require directives. see Ruhoh::Processor
      #  4. Sprockets will compile the bundled-asset as normal.
      #  5. Cleanup the bundled-asset.
      #
      # Considerations:
      # There is only one dependency graph. We don't recognize nested
      # dependencies (dependencies in dependencies) because its quite unecessary.
      # What about javascript you ask? use AMD (require.js)
      def self.run(target, page)
        env = Sprockets::Environment.new(Ruhoh.paths.theme)
        env.logger = ::Logger.new(STDOUT)
        env.append_path(Ruhoh.paths.theme)  
        env.unregister_processor('text/css', Sprockets::DirectiveProcessor)
        env.register_processor('text/css', SprocketsProcessor)
        
        url = Ruhoh.urls.theme_stylesheets.gsub(/^\//, '')
        theme = Ruhoh::Utils.url_to_path(url, target)
        FileUtils.mkdir_p theme
        manifest = Sprockets::Manifest.new(env, theme)
        
        # Parse theme_config to create `bundled-asset` : `dependencies` dictionary.
        # Note we create the bundled-asset and inject JSON dependencies.
        stylesheets = {}
        Ruhoh::DB.theme_config[Ruhoh.names.stylesheets].each do |key, value|
          filename = "#{key}.css"
          path = File.join(Ruhoh.paths.theme, filename)
          File.open(path, 'w:UTF-8') {|f| a = {"paths" => value}; f.puts a.to_json }
          stylesheets[filename] = path
        end

        manifest.compile(stylesheets.keys)
        FileUtils.rm stylesheets.values #cleanup
      end

    end #SprocketsCompiler
  end #Compiler
end #Ruhoh