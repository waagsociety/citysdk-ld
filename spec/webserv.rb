require 'sinatra'
require 'json'

post '/ngsi' do 
  request.body.read
end

post '/steden.inw' do
  request.body.rewind
  data = JSON.parse request.body.read
  {inw: 1111}.to_json
end
