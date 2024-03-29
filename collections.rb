require 'rubygems'
require 'datamapper'
gem 'dm-core'
gem 'dm-mongo-adapter'

DataMapper.setup(:default,
                 :adapter => 'mongo',
                 :database => 'fuji_ftp'
                 )

class LogInOut
  include DataMapper::Mongo::Resource

  property :id,         ObjectId
  property :time_in,    DateTime
  property :time_out,   DateTime
  property :duration,   Integer

  has n, :transfer
end

class Transfer
  include DataMapper::Mongo::Resource

  property :id,         ObjectId
  property :file_name,  String
  property :file_size,  Integer
  property :size_send,  Integer

  belongs_to :logInOut
end

DataMapper.finalize
