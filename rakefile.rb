task :test do
  sh "dub test --nodeps"
end

task :run do
  sh "dub run"
end

task :default => :test
