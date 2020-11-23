# frozen_string_literal: true

begin
  # Rubocop stuff
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  warn 'Rubocop, or one of its dependencies, is not available.'
end

task default: [:rubocop]
