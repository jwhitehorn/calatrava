module Calatrava

  class AppBuilder
    include Rake::DSL

    def initialize(platform, output_dir, manifest)
      @platform, @output_dir, @manifest = platform, output_dir, manifest
    end

    def build_dir;
      @output_dir;
    end

    def build_html_dir;
      "#{build_dir}/views";
    end

    def build_scripts_dir;
      "#{build_dir}/scripts";
    end

    def build_images_dir;
      "#{build_dir}/images";
    end

    def build_styles_dir;
      "#{build_dir}/styles";
    end

    def js_files
      @manifest.js_files
    end

    def coffee_files
      coffee_files = @manifest.coffee_files + [Calatrava::Project.current.config.path('env.coffee')]
      coffee_files.each do |cf|
        raise "error" if js_files.include?(File.basename(cf, '.coffee'))
      end
    end
    
    def js_file(cf)
      "#{build_scripts_dir}/#{File.basename(cf, '.coffee')}.js"
    end

    def change_path_to_relative files, &change_file_path
      build_path = Pathname.new(File.dirname(build_dir))
      files.collect do |file_to_add|
        Pathname.new(change_file_path.call(file_to_add)).relative_path_from(build_path).to_s
      end
    end

    def library_files
      change_path_to_relative @manifest.kernel_libraries do |js_library|
        "#{build_scripts_dir}/#{File.basename(js_library)}"
      end
    end

    def feature_files
      change_path_to_relative @manifest.kernel_bootstrap do |coffee_file|
        js_file(coffee_file)
      end
    end

    def load_instructions
      feature_files.concat(library_files).join($/)
    end

    def haml_files
      @manifest.haml_files
    end

    def check_if_javascript_already_exist(cf)
      js_files.each do |js_file|
        js_file_name = File.basename(js_file, '.js')
        cf_file_name = File.basename(cf, '.coffee')
        raise "Cannot compile the file. There is an existing JavaScript file with the same name: '#{js_file_name}'" if js_file_name == cf_file_name
      end
    end

    def builder_task
      directory build_html_dir
      directory build_images_dir
      directory build_scripts_dir
      directory build_styles_dir

      app_files = haml_files.collect do |hf|
        file "#{build_html_dir}/#{File.basename(hf, '.haml')}.html" => [build_html_dir, hf] do
          HamlSupport::compile_hybrid_page hf, build_html_dir, :platform => 'ios'
        end
      end

      app_files += js_files.collect do |jf|
        file "#{build_scripts_dir}/#{File.basename(jf)}" => [build_scripts_dir, jf] do
          FileUtils.copy(jf, "#{build_scripts_dir}/#{File.basename(jf)}")
        end
      end

      app_files += coffee_files.collect do |cf|
        file js_file(cf) => [build_scripts_dir, cf] do
          check_if_javascript_already_exist cf
          coffee cf, build_scripts_dir
        end
      end

      app_files += coffee_files.collect { |cf| cf.to_task }
      app_files += @manifest.css_tasks(build_styles_dir)
      app_files << file("#{build_dir}/load_file.txt" => [build_dir,
                                                         @manifest.src_file,
                                                         transient("#{@platform}_coffee", @manifest.kernel_bootstrap)
                                                        ]) do |t|
        File.open(t.name, "w+") { |f| f.puts load_instructions }
      end

      task :shared => [build_images_dir, build_scripts_dir] do
        cp_ne "assets/images/*", build_images_dir
        cp_ne "assets/lib/*.js", build_scripts_dir
        cp_ne "#{@platform}/res/js/*.js", build_scripts_dir
      end

      task :app => [:shared] + app_files
    end


  end

end
