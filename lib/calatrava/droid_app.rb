module Calatrava
  
  class DroidApp
    include Rake::DSL

    def initialize(path, proj_name, manifest)
      @path, @proj_name, @manifest = path, proj_name, manifest
      @app_builder = AppBuilder.new('droid', "droid/#{@proj_name}/assets/calatrava", @manifest)
    end

    def install_tasks
      app_task = @app_builder.builder_task

      app_task.prerequisites << file(@app_builder.as_js_file('droid/app/bridge.coffee') => 'droid/app/bridge.coffee') do
        coffee 'droid/app/bridge.coffee', @app_builder.build_scripts_dir
      end

      task :resolve => "droid/#{@proj_name}/ivy/ivy.xml" do
        cd "droid/#{@proj_name}" do
          sh "ant -f ant/calatrava.xml resolve"
        end
      end

      desc "Bootstraps the Droid app"
      task :bootstrap => :resolve

      desc "Builds the Android app"
      task :build => [:resolve, app_task] do
        cd "droid/#{@proj_name}" do
          sh "ant clean debug"
        end
      end

      desc "Publishes the built Android app as an artifact"
      task :publish => :build do
        artifact("droid/#{@proj_name}/bin/#{@proj_name}-debug.apk", ENV['CALATRAVA_ENV'])
      end

      desc "Deploy app to device/emulator"
      task :deploy => :publish do
        sh "adb install -r artifacts/#{ENV['CALATRAVA_ENV']}/#{@proj_name}-debug.apk"
      end
      
      desc "Runs (and deploys) the app to the device/emulator"
      task :run => :deploy do
        sh "adb shell am start -n com.#{@proj_name}/.MAIN"
      end

      desc "Clean droid"
      task :clean do
        rm_rf @app_builder.build_dir
        cd "droid/#{@proj_name}" do
          sh "ant clean"
        end
      end
      
    end
  end

end
