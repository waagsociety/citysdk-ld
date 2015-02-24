# encoding: UTF-8

module CitySDKLD

  # function 'cdk_id_from_name' uses function 'to_ascii' from gem 'i18n'
  # to convert non-ASCII characters (é, ñ) to ASCII.
  # To prevent the following message:
  #   "I18n.enforce_available_locales will default to true in the future.
  #    If you really want to skip validation of your locale you can
  #    set I18n.enforce_available_locales = false to avoid this message."
  # set:
  I18n.enforce_available_locales = false

  MEMCACHED_NAMESPACE = 'citysdk_ld'
  NGSI_COMPAT = true

  # hard-coded list of RDF prefixes, used by JSON-LD and Turtle serializers
  PREFIXES = {
    dc: 'http://purl.org/dc/elements/1.1/',
    rdf: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    rdfs: 'http://www.w3.org/2000/01/rdf-schema#',
    owl: 'http://www.w3.org/2002/07/owl#',
    xsd: 'http://www.w3.org/2001/XMLSchema#',
    org: 'http://www.w3.org/ns/org#',
    foaf: 'http://xmlns.com/foaf/0.1/',
    dcat: 'http://www.w3.org/ns/dcat#',
    geos: 'http://www.opengis.net/ont/geosparql#',
    dbpedia: "http://dbpedia.org/resource/",
    :'dbpedia-owl' => "http://dbpedia.org/ontology/"
  }

  ##########################################################################################
  # memcached utilities
  ##########################################################################################

  # To flush local instance of memcached:
  #   echo 'flush_all' | nc localhost 11211

  def self.memcached_new
    @@memcache = Dalli::Client.new('127.0.0.1:11211', { expires_in: 300, compress: true, namespace: "#{MEMCACHED_NAMESPACE},#{ENV["RACK_ENV"]}" })
  end

  def self.memcached_get(key)
    begin
      return @@memcache.get(key)
    rescue
      begin
        @@memcache = Dalli::Client.new('127.0.0.1:11211', { expires_in: 300, compress: true, namespace: "#{MEMCACHED_NAMESPACE},#{ENV["RACK_ENV"]}" })
      rescue
        $stderr.puts "Failed connecting to memcache: #{e.message}\n\n"
        @@memcache = nil
      end
    end
  end

  # TODO: memcached layers cache and connection still might be error-prone!
  def self.memcached_set(key, value, ttl=300, try=0)
    begin
      return @@memcache.set(key, value, ttl)
    rescue
      begin
        memcached_new
        memcached_set(key, value, ttl, try + 1) if try == 0
      rescue
        $stderr.puts "Failed connecting to memcache: #{e.message}\n\n"
        @@memcache = nil
      end
    end
  end

  ##########################################################################################
  # cdk_id generation
  ##########################################################################################

  def self.password_secure?(password)
    c = 0
    c+=1 if password =~ /\d/
    c+=1 if password =~ /[A-Z]/
    c+=1 if password =~ /\!\@\#\$\%\^\&\*\(\)\[\}\{\]/

    if( (password.length >= 15) ||
        (password.length >= 10 && c > 0) ||
        (password.length >=  8 && c > 1) ||
        (password.length >=  4 && c > 2)
      )
      [true, nil]
    else
      [false, 'Password needs to be longer, or contain numbers, capitals or symbols']
    end
  end


  ##########################################################################################
  # cdk_id generation
  ##########################################################################################

  # Create alphanumeric hashes, 22 characters long
  # base62 = numbers + lower case + upper case = 10 + 26 + 26 = 62
  # Example hash: 22pOqosrbX0KF6zCQiPj49
  def self.md5_base62(s)
    Digest::MD5.hexdigest(s).to_i(16).base62_encode
  end

  def self.cdk_id_from_id(layer, id)
    cdk_id_from_name layer, id
  end
  
  def self.cdk_id_from_name(layer, text)
    # Normalize text:
    #  downcase, strip,
    #  normalize (é = e, ü = u),
    #  remove ', ", `,
    #  replace sequences of non-word characters by '.',
    #  Remove leading and trailing '.'

    n = text.to_s.downcase.strip
      .gsub(/['"`]/, '')
      .gsub(/\W+/, '.')
      .gsub(/((\.$)|(^\.))/, '')
    "#{layer}.#{::I18n.transliterate(n)}"
  end
  

  def self.generate_cdk_id_with_hash(layer, id)
    self.md5_base62(layer + "::" + id.to_s)
  end

  ##########################################################################################
  # Exceptions
  ##########################################################################################

  # formats PostgreSQL/Sequel error, and raises error using api.error!
  def self.format_sequel_error(e, query)
    msg = case e.wrapped_exception
      when PG::UniqueViolation
        if e.message.include? 'Key (layer_id, object_id)'
          # TODO: specify which object/layer. e.message:
          # DETAIL: Key (layer_id, object_id)=(458, 1133) already exists.
          'Object already has data on this layer'
        else
          cdk_id = e.message.match(/\(cdk_id\)=\((.*)\)/).captures.first rescue nil
          if cdk_id
            "cdk_id must be unique: '#{cdk_id}'"
          else
            e.message
          end
        end
      when PG::RaiseException, PG::InvalidParameterValue
        # Custom error raised from CitySDK LD PL/pgSQL function - message is of form:
        # "ERROR:  <error message>".
        # Remove string "ERROR:  ":
        e.message[(e.message.index('ERROR:') + 6)..-1].strip
      when PG::InternalError
        if e.message.include? 'invalid GeoJson representation'
         "Invalid GeoJSON geometry encountered"
        else
          e.message
        end
      when PG::CheckViolation
        if e.message.include? 'constraint_name_alphanumeric'
          field = query[:resource] == :objects ? 'cdk_id' : 'name'
          "'#{field}' can only contain alphanumeric characters, underscores and periods"
        elsif e.message.include? 'no_geometrycollection'
          "GeoJSON GeometryCollections are not allowed as object geometry"
        else
          e.message
        end
      else
        e.message
      end
    query[:api].error! msg, 422
  end

end

##########################################################################################
# Additional functions
##########################################################################################

# For debugging purposes; log anything in JSON pretty format
def jsonlog(o)
  puts JSON.pretty_generate({ o.class.to_s => o })
end

class Object
  def deep_copy
    Marshal.load(Marshal.dump(self))
  end
  def blank?
    return false if self.class == Symbol
    self.nil? or (self.class==String and self.strip == '') or (self.respond_to?(:empty?) ? self.empty? : false)
  end
end

class String
  def round_coordinates(precision)
    self.gsub(/(\d+)\.(\d{#{precision}})\d+/, '\1.\2')
  end

  def is_number?
    true if Float(self) rescue false
  end

  def to_bool
    case self.downcase
    when 'true'
      true
    when 'false'
      false
    else
      nil
    end
  end
end
