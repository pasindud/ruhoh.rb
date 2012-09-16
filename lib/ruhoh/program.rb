require 'sprockets'
class Ruhoh
  module Program
    
    # Public: A program for running ruhoh as a rack application
    # which renders singular pages via their URL.
    # 
    # Examples
    #
    #  In config.ru:
    #
    #   require 'ruhoh'
    #   run Ruhoh::Program.preview
    #
    # Returns: A new Rack builder object which should work inside config.ru
    def self.preview(opts={})
      opts[:watch] ||= true
      opts[:env] ||= 'development'
      
      Ruhoh.setup
      Ruhoh.config.env = opts[:env]
      Ruhoh.setup_paths
      Ruhoh.setup_urls
      Ruhoh.setup_plugins unless opts[:enable_plugins] == false
      
      Ruhoh::DB.update_all
      
      Ruhoh::Watch.start if opts[:watch]
      Rack::Builder.new {
        use Rack::Lint
        use Rack::ShowExceptions

        map "#{Ruhoh.urls.theme}/" do
          environment = Sprockets::Environment.new
          environment.append_path Ruhoh.paths.theme
          run environment
        end
        
        map "#{Ruhoh.urls.widgets}/" do
          environment = Sprockets::Environment.new
          environment.append_path Ruhoh.paths.widgets
          run environment
        end
        
        map "#{Ruhoh.urls.media}/" do
          environment = Sprockets::Environment.new
          environment.append_path Ruhoh.paths.media
          run environment
        end
        
        map '/' do
          run Ruhoh::Previewer.new(Ruhoh::Page.new)
        end
      }
    end
    
    # Public: A program for compiling to a static website.
    # The compile environment should always be 'production' in order
    # to properly omit drafts and other development-only settings.
    def self.compile(target)
      Ruhoh.setup
      Ruhoh.config.env = 'production'
      Ruhoh.setup_paths
      Ruhoh.setup_urls
      Ruhoh.setup_plugins
      
      Ruhoh::DB.update_all
      Ruhoh::Compiler.compile(target)
    end
    
  end #Program
end #Ruhoh