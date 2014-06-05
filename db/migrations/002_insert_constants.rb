#encoding: utf-8

Sequel.migration do
  up do
    $stderr.puts('Inserting default data...')

    # Default categories
    self[:categories].insert(id: 0, name: 'none', title: 'None')
    self[:categories].insert(name: 'natural', title: 'Natural')
    self[:categories].insert(name: 'cultural', title: 'Cultural')
    self[:categories].insert(name: 'civic', title: 'Civic')
    self[:categories].insert(name: 'tourism', title: 'Tourism')
    self[:categories].insert(name: 'mobility', title: 'Mobility')
    self[:categories].insert(name: 'administrative', title: 'Administrative')
    self[:categories].insert(name: 'environment', title: 'Environment')
    self[:categories].insert(name: 'health', title: 'Health')
    self[:categories].insert(name: 'education', title: 'Education')
    self[:categories].insert(name: 'security', title: 'Security')
    self[:categories].insert(name: 'commercial', title: 'Commercial')

    # Default owner
    self[:owners].insert(id: 0, name: 'citysdk', fullname: 'CitySDK', organization: 'CitySDK LD', email: 'citysdk@waag.org', admin: true)

    # layer -1, this is where objects end up which layer is removed while still have data attached
    self[:layers].insert(id: -1, name: 'none', title: 'None', description: 'Layer for objects from removed layers', category_id: 0, owner_id: 0)

  end

  down do
    DB[:layers].truncate(cascade: true)
    DB[:owners].truncate(cascade: true)
    DB[:categories].truncate(cascade: true)
  end

end
