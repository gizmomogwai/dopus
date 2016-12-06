desc 'run test'
task :test do
  sh "dub test --nodeps"
end

desc 'run app'
task :run do
  sh "dub run"
end

desc 'clean'
task :clean do
  sh "dub clean"
  sh "find . -name '*.lst' -delete"
  sh "find . -name '*~' -delete"
  sh "rm dopus"
end

task :default => :test
