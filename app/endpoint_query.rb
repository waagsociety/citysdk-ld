# encoding: UTF-8

class Grape::Endpoint
  def do_query(resource, single = false)
    q = CitySDKLD::Query.new resource, single, env
    q.execute
  end
end
