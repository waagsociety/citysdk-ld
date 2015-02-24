# encoding: UTF-8

class Grape::Endpoint
  def do_query(resource, single = false)
    header 'Content-Type', 'application/json; charset=utf-8'
    header 'Access-Control-Allow-Origin', '*'
    q = CitySDKLD::Query.new resource, single, env
    q.execute
  end
end
