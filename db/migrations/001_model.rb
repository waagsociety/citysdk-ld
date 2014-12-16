# encoding: UTF-8

Sequel.migration do

  up do
    $stderr.puts('Creating tables...')

    ######################################################################
    # Functions:
    ######################################################################

    # Add geometry column to table, including constraint and index
    def add_geometry_column(table)
      sql = <<-SQL
        SELECT AddGeometryColumn('%s', 'geom', 4326, 'GEOMETRY', 2);

        ALTER TABLE %s ADD CONSTRAINT constraint_geom_no_geometrycollection
            CHECK (GeometryType(geom) != 'GEOMETRYCOLLECTION');

        CREATE INDEX ON %s USING gist (geom);
      SQL

      run sql % ([table.to_s] * 3)
    end

    # Creates constraint allowing alphanumeric characters, and '.' on name column
    def add_alphanumeric_name_constraint(table, column = :name)
      sql = <<-SQL
        ALTER TABLE %s ADD CONSTRAINT constraint_name_alphanumeric
          CHECK (%s SIMILAR TO '\\w+[\\w-]*(\\.[\\w-]+)*');
      SQL

      run sql % [table.to_s, column.to_s]
    end

    ######################################################################
    # Table 'owners':
    ######################################################################

    create_table! :owners do
      column :id, 'serial', primary_key: true, unique: true
      String :name, null: false, unique: true
      String :fullname, null: false
      String :email, null: false, unique: true
      bool :admin, default: false
      String :website
      String :organization
      column :domains, 'text[]'
      String :password
      String :salt
      String :session_key
      timestamptz :session_expires
      timestamptz :created_at, null: false, default: :now.sql_function
    end

    add_alphanumeric_name_constraint :owners

    ######################################################################
    # Table 'categories':
    ######################################################################

    create_table! :categories do
      column :id, 'serial', primary_key: true, unique: true
      String :name, null: false
    end

    add_alphanumeric_name_constraint :categories

    ######################################################################
    # Table 'layers':
    ######################################################################

    create_table! :layers do
      column :id, 'serial', primary_key: true, unique: true

      foreign_key :owner_id, :owners, type: 'integer', null: false, on_delete: :cascade
      foreign_key :category_id, :categories, type: 'integer', null: false
      foreign_key :depends_on_layer_id, :layers, type: 'integer', on_delete: :cascade

      String  :name, null: false, unique: true
      String  :title
      String  :description
      String  :subcategory
      String  :rdf_type
      column  :rdf_prefixes, 'hstore'
      column  :data_sources, 'text[]'
      String  :licence
      bool    :authoritative, default: false
      column  :context, 'json'
      integer :update_rate
      String  :webservice_url
      String  :sample_url
      timestamptz :imported_at
      timestamptz :created_at, null: false, default: :now.sql_function

      # Indexes:
      full_text_index :title
    end

    add_geometry_column :layers
    add_alphanumeric_name_constraint :layers

    ######################################################################
    # Table 'objects':
    ######################################################################

    create_table! :objects do
      # Columns:
      column :id, 'serial', primary_key: true, unique: true

      foreign_key :layer_id, :layers, type: 'integer', null: false, on_delete: :cascade

      String :cdk_id, null: false, unique: true
      String :title
      timestamptz :created_at, null: false, default: :now.sql_function
      timestamptz :updated_at, null: false, default: :now.sql_function

      # Indexes:
      index :layer_id
      full_text_index :title
      full_text_index :cdk_id
      index Sequel.function(:lower, :title)
    end

    add_geometry_column :objects
    add_alphanumeric_name_constraint :objects, :cdk_id

    ######################################################################
    # Table 'object_data':
    ######################################################################

    create_table! :object_data do
      column :id, 'serial', primary_key: true, unique: true

      foreign_key :object_id, :objects, type: 'bigint', null: false, on_delete: :cascade
      foreign_key :layer_id, :layers, type: 'integer', null: false, on_delete: :cascade

      column :data, 'hstore'
      timestamptz :created_at, null: false, default: :now.sql_function
      timestamptz :updated_at, null: false, default: :now.sql_function

      # Constraints:
      unique [:layer_id, :object_id]

      # Indexes:
      index :layer_id
      index :object_id
      index :data, index_type: :gin
    end

    ######################################################################
    # Table 'fields':
    ######################################################################

    create_table! :fields do
      primary_key [:layer_id, :name], unique: true

      foreign_key :layer_id, :layers, type: 'integer', null: false, on_delete: :cascade
      String :name, null: false
      String :type
      String :unit
      String :lang
      String :equivalent_property
      String :description
    end

    add_alphanumeric_name_constraint :fields

    ######################################################################
    # FI-Ware specific:
    ######################################################################

    create_table! :ngsi_subscriptions do
      String :cdk_id, null: false
      String :attributes
      String :subscription_id, null: false
      integer :layer_id
      integer :referrer_id
      timestamptz :ends_at, null: false, default: :now.sql_function
    end

    create_table! :ngsi_referrers do
      column :id, 'serial', primary_key: true, unique: true
      String :url, null: false
    end

  end

  down do
    drop_table? :ngsi_referrers, cascade: true
    drop_table? :ngsi_subscriptions, cascade: true
    drop_table? :objects, cascade: true
    drop_table? :object_data, cascade: true
    drop_table? :fields, cascade: true
    drop_table? :categories, cascade: true
    drop_table? :owners, cascade: true
    drop_table? :layers, cascade: true
  end

end
