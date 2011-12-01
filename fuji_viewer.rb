require 'rubygems'
gem 'datamapper', '=1.1.0'
gem 'dm-core', '=1.1.0'
gem 'dm-mongo-adapter'
load 'collections.rb'

puts  "Il y a eu " + LogInOut.all().count.to_s + " connections en tous"
