desc 'run test'
task :test do
  sh "dub test --nodeps"
end

desc 'run app'
task :run do
  sh "dub run"
end

task :default => :test
