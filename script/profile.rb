#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), '..', 'lib', 'dm-core')

require 'rubygems'

gem 'ruby-prof', '~>0.7.0'
require 'ruby-prof'

gem 'faker', '~>0.3.1'
require 'faker'

OUTPUT = DataMapper.root / 'profile_results.txt'
#OUTPUT = DataMapper.root / 'profile_results.html'

SOCKET_FILE = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  /tmp/mysqld.sock
  /tmp/mysql.sock
  /var/mysql/mysql.sock
  /var/run/mysqld/mysqld.sock
]).find { |path| path.socket? }

configuration_options = {
  :adapter  => 'mysql',
  :database => 'data_mapper_1',
  :host     => 'localhost',
  :username => 'root',
  :password => '',
  :socket   => SOCKET_FILE,
}

DataMapper::Logger.new(DataMapper.root / 'log' / 'dm.log', :debug)
DataMapper.setup(:default, configuration_options)

if configuration_options[:adapter]
  sqlfile       = File.join(File.dirname(__FILE__),'..','tmp','performance.sql')
  mysql_bin     = %w[ mysql mysql5 ].select { |bin| `which #{bin}`.length > 0 }
  mysqldump_bin = %w[ mysqldump mysqldump5 ].select { |bin| `which #{bin}`.length > 0 }
end

class Exhibit
  include DataMapper::Resource

  property :id,         Serial
  property :name,       String
  property :zoo_id,     Integer
  property :notes,      Text, :lazy => true
  property :created_on, Date
#  property :updated_at, DateTime

  auto_migrate!
  create  # create one row for testing
end

touch_attributes = lambda do |exhibits|
  [*exhibits].each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
    exhibit.updated_at
  end
end

touch_relationships = lambda do |exhibits|
  [*exhibits].each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
    exhibit.user
  end
end

# RubyProf, making profiling Ruby pretty since 1899!
def profile(&b)
  result  = RubyProf.profile &b
  printer = RubyProf::FlatPrinter.new(result)
  #printer = RubyProf::GraphHtmlPrinter.new(result)
  printer.print(OUTPUT.open('w+'))
end

c = configuration_options

if sqlfile && File.exists?(sqlfile)
  puts "Found data-file. Importing from #{sqlfile}"
  #adapter.execute("LOAD DATA LOCAL INFILE '#{sqlfile}' INTO TABLE exhibits")
  `#{mysql_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} < #{sqlfile}`
else
  puts 'Generating data for benchmarking...'

  Exhibit.auto_migrate!

  users = []
  exhibits = []

  # pre-compute the insert statements and fake data compilation,
  # so the benchmarks below show the actual runtime for the execute
  # method, minus the setup steps

  # Using the same paragraph for all exhibits because it is very slow
  # to generate unique paragraphs for all exhibits.
  paragraph = Faker::Lorem.paragraphs.join($/)

  10_000.times do |i|
    users << [
      'INSERT INTO `users` (`name`,`email`,`created_on`) VALUES (?, ?, ?)',
      Faker::Name.name,
      Faker::Internet.email,
      Date.today
    ]

    exhibits << [
      'INSERT INTO `exhibits` (`name`, `zoo_id`, `user_id`, `notes`, `created_on`) VALUES (?, ?, ?, ?, ?)',
      Faker::Company.name,
      rand(10).ceil,
      i,
      paragraph,#Faker::Lorem.paragraphs.join($/),
      Date.today
    ]
  end

  puts 'Inserting 10,000 users...'
  10_000.times { |i| adapter.execute(*users.at(i)) }
  puts 'Inserting 10,000 exhibits...'
  10_000.times { |i| adapter.execute(*exhibits.at(i)) }

  if sqlfile
    answer = nil
    until answer && answer[/^$|y|yes|n|no/]
      print('Would you like to dump data into tmp/performance.sql (for faster setup)? [Yn]');
      STDOUT.flush
      answer = gets
    end

    if answer[/^$|y|yes/]
      File.makedirs(File.dirname(sqlfile))
      #adapter.execute("SELECT * INTO OUTFILE '#{sqlfile}' FROM exhibits;")
      `#{mysqldump_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} exhibits users > #{sqlfile}`
      puts "File saved\n"
    end
  end
end

TIMES = 10_000

profile do
#  dm_obj = Exhibit.get(1)
#
#  puts 'Model#id'
#  (TIMES * 100).times { dm_obj.id }
#
#  puts 'Model.new (instantiation)'
#  TIMES.times { Exhibit.new }
#
#  puts 'Model.new (setting attributes)'
#  TIMES.times { Exhibit.new(:name => 'sam', :zoo_id => 1) }
#
#  puts 'Model.get specific (not cached)'
#  TIMES.times { touch_attributes[Exhibit.get(1)] }
#
#  puts 'Model.get specific (cached)'
#  repository(:default) do
#    TIMES.times { touch_attributes[Exhibit.get(1)] }
#  end
#
#  puts 'Model.first'
#  TIMES.times { touch_attributes[Exhibit.first] }
#
#  puts 'Model.all limit(100)'
#  (TIMES / 10).ceil.times { touch_attributes[Exhibit.all(:limit => 100)] }
#
#  puts 'Model.all limit(100) with relationship'
#  (TIMES / 10).ceil.times { touch_relationships[Exhibit.all(:limit => 100)] }
#
#  puts 'Model.all limit(10,000)'
#  (TIMES / 1000).ceil { touch_attributes[Exhibit.all(:limit => 10_000)] }
#
#  create_exhibit = {
#    :name       => Faker::Company.name,
#    :zoo_id     => rand(10).ceil,
#    :notes      => Faker::Lorem.paragraphs.join($/),
#    :created_on => Date.today
#  }
#
#  puts 'Model.create'
#  TIMES.times { Exhibit.create(create_exhibit) }
#
#  attrs_first  = { :name => 'sam', :zoo_id => 1 }
#  attrs_second = { :name => 'tom', :zoo_id => 1 }
#
#  puts 'Resource#attributes='
#  TIMES.times { e = Exhibit.new(attrs_first); e.attributes = attrs_second }
#
#  puts 'Resource#update'
#  TIMES.times { e = Exhibit.get(1); e.name = 'bob'; e.save }

  puts 'Resource#destroy'
  TIMES.times { Exhibit.first.destroy }

#  puts 'Model.transaction'
#  TIMES.times { Exhibit.transaction { Exhibit.new } }
end

puts "Done!"
