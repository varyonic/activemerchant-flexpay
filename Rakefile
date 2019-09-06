require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task :default => 'test:units'

namespace :test do
  Rake::TestTask.new(:units) do |t|
    t.pattern = 'test/unit/**/*_test.rb'
    t.libs << 'test'
    t.verbose = true
  end

  desc 'Run all tests that do not require network access'
  task :local => ['test:units', 'rubocop']

  Rake::TestTask.new(:remote) do |t|
    t.pattern = 'test/remote/**/*_test.rb'
    t.libs << 'test'
    t.verbose = true
  end
end
