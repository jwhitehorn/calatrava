module Calatrava

  class MobileWebApp
    include Rake::DSL

    def initialize(path, manifest)
      @path, @manifest = path, manifest
      @apache = Apache.new
    end

    def build_dir ; "#{@path}/web/public" ; end
    def scripts_build_dir ; "#{build_dir}/scripts" ; end
    def styles_build_dir ; "#{build_dir}/styles" ; end
    def images_build_dir ; "#{build_dir}/images" ; end

    def coffee_files
      Dir.chdir @path do
        core_coffee = ['bridge', 'init'].collect { |l| "web/app/source/#{l}.coffee" }
        core_coffee += @manifest.coffee_files.select { |cf| cf =~ /calatrava.coffee$/ }
        web_coffee = Dir['web/app/source/*.coffee'] - core_coffee
        mf_coffee = @manifest.coffee_files.reject { |cf| cf =~ /calatrava.coffee$/ }
        env_file = OutputFile.new(scripts_build_dir, Calatrava::Project.current.config.path('env.coffee'), ['configure:calatrava_env'])
        (core_coffee + web_coffee + mf_coffee).collect { |cf| OutputFile.new(scripts_build_dir, cf) } + [env_file]
      end
    end

    def js_files
      Dir.chdir @path do
        mf_js = @manifest.js_files
        web_js = Dir['web/app/source/*.js']
        mf_js + web_js
      end
    end

    def haml_files
      Dir.chdir(@path) { @manifest.haml_files }
    end

    def scripts
      scripts = coffee_files.collect { |cf| "scripts/#{File.basename(cf, '.coffee')}.js" }
      scripts << js_files.collect { |jf| "scripts/#{File.basename(jf)}" unless jf.nil? }
      scripts.reject { | x | x.nil? }.flatten.uniq
    end

    def copy_js_files
      js_files.collect do | jf |
        FileUtils.mkdir_p("#{scripts_build_dir}")
        FileUtils.copy(jf, "#{scripts_build_dir}/#{File.basename(jf)}") unless jf.nil?
      end
    end

    def install_tasks
      directory build_dir
      directory scripts_build_dir
      directory styles_build_dir
      directory images_build_dir

      app_files = coffee_files.collect { |cf| cf.to_task }

      app_files << file("#{build_dir}/index.html" => [@manifest.src_file,
                                                      "web/app/views/index.haml",
                                                      transient('web_coffee', coffee_files),
                                                      transient('web_haml', haml_files)] + haml_files) do
        HamlSupport::compile "web/app/views/index.haml", build_dir
      end

      app_files += @manifest.css_tasks(styles_build_dir)

      task :shared => [images_build_dir, scripts_build_dir] do
        cp_ne "assets/images/*", File.join(build_dir, 'images')
        cp_ne "assets/lib/*.js", scripts_build_dir
        copy_js_files
      end        

      desc "Build the web app"
      task :build => app_files + [:shared]

      desc "Publishes the built web app as an artifact"
      task :publish => :build do
        artifact_dir(build_dir, 'web/public')
      end
      
      desc "Clean web app"
      task :clean => 'apache:clean' do
        rm_rf build_dir
      end

      desc "Auto compile shell and kernel files"
      task :autocompile do
        fork do
          exec "ruby ./.auto_compile.rb"
        end
      end

      namespace :apache do
        @apache.install_tasks
      end

    end
  end

end
