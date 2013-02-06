require 'active_record'
require 'workflow'

require './user'
require './target'
require './game'

ActiveRecord::Base.establish_connection({
  database: 'assassins',
  adapter:  'postgresql',
  encoding: 'unicode',
  pool:     5,
  username: 'root',
  password: '',
  reconnect: true
})
