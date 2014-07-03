#encoding: utf-8

Sequel.migration do
  up do
    $stderr.puts('Inserting default data...')

    # Default categories
    self[:categories].insert(id: 0, name: 'none')
    self[:categories].insert(name: 'geography')
    self[:categories].insert(name: 'natural')
    self[:categories].insert(name: 'cultural')
    self[:categories].insert(name: 'civic')
    self[:categories].insert(name: 'tourism')
    self[:categories].insert(name: 'mobility')
    self[:categories].insert(name: 'administrative')
    self[:categories].insert(name: 'environment')
    self[:categories].insert(name: 'health')
    self[:categories].insert(name: 'education')
    self[:categories].insert(name: 'security')
    self[:categories].insert(name: 'commercial')

    # Default owner
    self[:owners].insert(id: 0, name: 'citysdk', fullname: 'CitySDK', organization: 'CitySDK LD', email: 'citysdk@waag.org', admin: true, salt: 'randomsalt', password: '7d4e9594b2816a49282fa8a123df21cf') # password = 'ChangeMeNow'

    # layer -1, this is where objects end up which layer is removed while still have data attached
    self[:layers].insert(id: -1, name: 'none', title: 'None', description: 'Layer for objects from removed layers', category_id: 0, owner_id: 0)

  end

  down do
    DB[:layers].truncate(cascade: true)
    DB[:owners].truncate(cascade: true)
    DB[:categories].truncate(cascade: true)
  end

end
