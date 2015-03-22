require 'json'
require 'fileutils'
require 'ostruct'
require 'semantic'

module Chest
  class Plugin
    attr_reader :name, :options

    class InvalidArgumentError < StandardError; end

    def initialize(name, options=nil)
      @name = name
      @options = OpenStruct.new(options)

      @registry = Chest::Registry.new
    end

    def path
      File.join(PLUGINS_FOLDER, @name)
    end

    def type
      @options.type
    end

    def install
      fetch_method = "fetch_#{type}"
      if respond_to?(fetch_method, true) && self.send(fetch_method)
        manifest = Manifest.new
        manifest.add_plugin(@name, to_option)
        manifest.save
      else
        raise "Unknown strategy type: #{type}"
      end
    end

    def uninstall
      if Dir.exist?(path) && FileUtils.rm_r(path)
        manifest = Manifest.new
        manifest.remove_plugin(@name)
        manifest.save
      else
        raise "#{@name} doesn't exist"
      end
    end

    def update
      return unless outdated?

      fetch_method = "update_#{type}"
      if respond_to?(fetch_method, true) && self.send(fetch_method)
        manifest = Manifest.new
        manifest.add_plugin(@name, to_option)
        manifest.save
      else
        raise "Unknown strategy type: #{type}"
      end
    end

    def outdated?
      case type
      when :chest
        package = @registry.fetch_package(name)
        return true unless package['version']
        return Semantic::Version.new(@options.version) < Semantic::Version.new(package['version'])
      when :git
        true
      when :direct
        true
      end
    end

    class << self
      def create_from_query(query, alias_name=nil)
        name, options = parse_query(query)
        new(alias_name || name, options)
      end

      def all
        Manifest.new.plugins
      end

      def parse_query(query)
        if query =~ /\.git$/
          name = File.basename(query, '.*')
          url  = query
          [
            name,
            {
              type: :git,
              url: query
            }
          ]
        elsif query =~ /\A([a-zA-Z0-9_\-]+)\/([a-zA-Z0-9_\-]+)\z/
          name = $2
          url  = "https://github.com/#{$1}/#{$2}.git"
          [
            name,
            {
              type: :git,
              url: url
            }
          ]
        elsif query =~ /\A([a-zA-Z0-9_\-]+)(?:@([a-zA-Z0-9\-\.]+))?\z/
          name = $1
          package = Chest::Registry.new.fetch_package(name)
          version = $2 || package['version']
          [
            name,
            {
              type: :chest,
              version: version
            }
          ]
        else
          raise InvalidArgumentError, "Specify valid query: #{query}"
        end
      end
    end

    private

    def to_option
      case type
      when :chest
        @options.version
      when :git
        @options.url
      when :direct
        @options.url
      end
    end

    def latest_version
      @registry.fetch_package(@name)['version']
    end

    def fetch_chest
      @registry.download_package(@name, @options.version, path)
    end

    def update_chest
      FileUtils.rm_r(path) if Dir.exist?(path)
      @options.version = latest_version
      @registry.download_package(@name, @options.version, path)
    end

    def fetch_git
      if system "git clone '#{@options.url}' '#{path}'"
        true
      else
        raise "Failed to install #{@options.url}"
      end
    end

    def update_git
      if system "cd '#{path}' && git pull"
        true
      else
        raise "Failed to update #{@name}"
      end
    end

    def fetch_direct
      system "curl -L '#{@options.url}' -o '#{path}'"
    end

    def update_direct
      system "curl -L '#{@options.url}' -o '#{path}'"
    end
  end
end
