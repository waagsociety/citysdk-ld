# encoding: UTF-8

require_relative 'filters.rb'

module Sequel

  class Dataset

    def execute_query(query)
      dataset = self
      query[:filters].each do |f|
        dataset = CitySDKLD::Filters.send f[:filter], dataset, f[:params], query
      end
      CitySDKLD::Filters.paginate dataset, query[:params], query
    end

  end
end
