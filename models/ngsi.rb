# encoding: UTF-8

class NGSI_Referer < Sequel::Model(:ngsi_referers)

  require 'faraday'

  def self.get_id(referer)
    n = NGSI_Referer.where(url: referer).first
    if n
      return n[:id]
    end
    return insert(url: referer)
  end

end

class NGSI_Subscription < Sequel::Model(:ngsi_subscriptions)

  require 'date'

  def self.get_expiry(duration)
    # decode ISO8901 Duration string...
    dd = DateTime.now
    dd = dd >> (12 * $1.to_i) if duration =~ /P([0-9]+Y)/       #years
    dd = dd >> $1.to_i if duration =~ /P.*([0-9]+M)/            #months
    dd = dd + (7 * $1.to_i ) if duration =~ /P.*([0-9]+W)/      #weeks
    dd = dd + $1.to_i if duration =~ /P.*([0-9]+D)/             #days
    dd = dd.to_time
    dd = dd + (3600 * $1.to_i) if duration =~ /P.*T.*([0-9]+H)/ #hours
    dd = dd + (60 * $1.to_i) if duration =~ /P.*T.*([0-9]+M)/   #minutes
    # we don't care about seconds
    return dd
  end

  def self.new_subscription(entities, data, sid)
    attributes = data[:attributes].is_a?(Array) ? data[:attributes].join(',') : data[:attributes]
    notification = data[:notifyConditions]
    ends_at = get_expiry(data[:duration])
    r_id = NGSI_Referer.get_id(data[:reference])
    case notification[0][:type]
    when 'ONCHANGE'
        entities.each do |e|
          s = {
            attributes: attributes,
            cdk_id: e[:cdk_id],
            layer_id: e[:layer_id],
            subscription_id: sid,
            ends_at: ends_at,
            referer_id: r_id
          }
          insert(s)
        end
    end
  end


  def self.post(subscription, data)
    type = CDKLayer.type_from_id(subscription[:layer_id])
    ref  = NGSI_Referer.where(id: subscription[:referer_id]).first

    d = {
      subscriptionId: subscription[:subscription_id],
      contextResponses: []
    }

    data.each_key do |k|
      if subscription[:attributes].index(k.to_s)
        ce = {
          contextElement: {
            attributes: [
              name: k.to_s,
              value: data[k],
              type: ''
            ],
            isPattern: false,
            id: subscription[:cdk_id],
            type: type
          },
          statusCode: {
            code: '200',
            reasonPhrase: 'OK'
          }
        }
        d[:contextResponses] << ce
      end
    end

    # do the actual post
    if ref
      begin
        connection = Faraday.new(url: ref[:url])
        response = connection.post do |req|
          req.url ''
          req.body = d.to_json + "\r\n"

          # open/read timeout in seconds
          req.options[:timeout] = 5

          # connection open timeout in seconds
          req.options[:open_timeout] = 2
        end
      rescue Exception => e
        puts "NGSI POST Exception: #{e.message}"
      end

    end

  end

end
