# encoding: UTF-8

class CDKOwner < Sequel::Model(:owners)
  one_to_many :layers

  def self.get_dataset(query)
    dataset = self.dataset
  end

  def self.execute_write(query)
    data = query[:data]

    written_owner_id = nil

    keys = [
      'name',
      'email',
      'website',
      'fullname',
      'domains',
      'organization',
      'password'
    ]

    # Make sure POST data contains only valid keys
    unless (data.keys - keys).empty?
      query[:api].error!("Incorrect keys found in POST data: #{(data.keys - keys).join(', ')}", 422)
    end

    salt = nil
    if data['password']
      password = data['password']
      secure, message = CitySDKLD.password_secure? password
      if secure
        salt = Digest::MD5.hexdigest(Random.rand().to_s)
        data['password'] = Digest::MD5.hexdigest(salt + password)
      else
        query[:api].error!(message, 422)
      end
    end

    if data['domains']
      begin
        data['domains'] = Sequel.pg_array(data['domains'].split(','))
      rescue
        query[:api].error!('Invalid domains encountered - must be comma-separated list of layer prefixes', 422)
      end
    end

    case query[:method]
    when :post
      # create

      owner_id = self.id_from_name data['name']
      if owner_id
        query[:api].error!("Owner already exists: #{data['name']}", 422)
      end

      unless data.keys.sort == keys.sort
        query[:api].error!("Cannot create owner, keys are missing in POST data: #{(keys - data.keys).join(', ')}", 422)
      end

      if salt
        data['salt'] = salt
      end

      # Set Location header
      # Location: http://endpoint/onwers/data[:name]

      written_owner_id = insert(data)
    when :patch
      # update

      if data['name']
        query[:api].error!('Owner name cannot be changed', 422)
      end

      if salt
        data['salt'] = salt
      end

      owner_id = self.id_from_name query[:params][:owner]
      if owner_id
        where(id: owner_id).update(data)
      else
        query[:api].error!("Owner not found: #{query[:params][:owner]}", 404)
      end
      written_owner_id = owner_id
    end

    dataset.where(id: written_owner_id)
  end

  def self.execute_delete(query)
    owner_id = id_from_name query[:params][:owner]
    if owner_id == 0
      query[:api].error!("Owner 'citysdk' cannot be deleted", 422)
    elsif owner_id
      # Move all objects on layers belonging to this owner that still
      # have data on other layers to layer = -1. See layer.rb > execute_delete
      # for example

      # TODO: create SQL function in 003_functions migration
      move_objects = <<-SQL
        UPDATE objects SET layer_id = -1
        WHERE id IN (
          SELECT id FROM objects AS o2
          WHERE layer_id IN (
            SELECT id FROM layers WHERE owner_id = ?
          ) AND EXISTS (
            SELECT TRUE FROM object_data
            WHERE o2.id = object_id
            AND object_data.layer_id != o2.layer_id
            AND o2.layer_id != -1
          )
        );
      SQL

      Sequel::Model.db.transaction do
        Sequel::Model.db.fetch(move_objects, owner_id).all
        count = where(id: owner_id).delete
        CDKObject.delete_orphans
        query[:api].error!("Database error while deleting owner '#{query[:params][:owner]}'", 422) if count == 0
      end
    else
      query[:api].error!("Owner not found: #{query[:params][:owner]}", 404)
    end
  end

  def self.id_from_name(name)
    owner = dataset.select(:id).where(name: name).first
    if owner
      owner[:id]
    else
      nil
    end
  end

  def self.make_hash(o)
    {
      name: o[:name],
      fullname: o[:fullname],
      email: o[:email],
      website: o[:website],
      organization: o[:organization],
      admin: o[:admin]
    }.delete_if {|_, v| not v or v == '' }
  end

end

