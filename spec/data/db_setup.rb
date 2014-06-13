d =  ::DATA.read
`psql postgres -c 'drop database if exists "citysdk-test"'`
`createdb citysdk-test`
`psql citysdk-test -c 'create extension postgis'`
`psql citysdk-test -c 'create extension hstore'`
`psql citysdk-test << #{d}`

__END__
SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;
COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';
SET search_path = public, pg_catalog;
CREATE FUNCTION cdk_id_to_internal(_cdk_id text) RETURNS bigint
    LANGUAGE plpgsql IMMUTABLE
    AS $$
        DECLARE
          _id bigint;
        BEGIN
          SELECT id INTO _id FROM objects
          WHERE _cdk_id = cdk_id;
          IF _id IS NULL THEN
            RAISE EXCEPTION 'Object not found: ''%''', _cdk_id;
          END IF;
          RETURN _id;
      END $$;


ALTER FUNCTION public.cdk_id_to_internal(_cdk_id text) OWNER TO tom;

CREATE FUNCTION update_layer_bounds(layer_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
        DECLARE object_data_bounds geometry;
        DECLARE object_bounds geometry;
        BEGIN
          object_data_bounds := (
            SELECT ST_SetSRID(ST_Extent(geom)::geometry, 4326) FROM objects
            JOIN object_data ON objects.id = object_data.object_id
              AND object_data.layer_id = layer_id
          );

          object_bounds := (
            SELECT ST_SetSRID(ST_Extent(geom)::geometry, 4326) FROM objects
              WHERE layer_id = layer
          );

          UPDATE layers SET geom = ST_Envelope(ST_Collect(object_data_bounds, object_bounds)) WHERE id = layer_id;
        END;
    $$;


ALTER FUNCTION public.update_layer_bounds(layer_id integer) OWNER TO tom;


CREATE FUNCTION update_layer_bounds_from_object() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        DECLARE
          layer_id integer := NEW.layer_id;
          box geometry := (SELECT geom FROM layers WHERE id = NEW.layer_id);
        BEGIN
          IF box IS NULL THEN
            UPDATE layers SET geom = ST_Envelope(ST_Buffer(ST_SetSRID(NEW.geom,4326), 0.0000001) ) WHERE id = layer_id;
          ELSE
            UPDATE layers SET geom = ST_Envelope(ST_Collect(NEW.geom, box)) WHERE id = layer_id;
          END IF;
          RETURN NULL;
        END;
    $$;


ALTER FUNCTION public.update_layer_bounds_from_object() OWNER TO tom;


CREATE FUNCTION update_layer_bounds_from_object_data() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        DECLARE
          layer_id integer := NEW.layer_id;
          box geometry := (SELECT geom FROM layers WHERE id = NEW.layer_id);
          geo geometry := (SELECT geom FROM objects WHERE id = NEW.object_id);
        begin
          IF box IS NULL THEN
            UPDATE layers SET geom = ST_Envelope(ST_Buffer(ST_SetSRID(geo, 4326), 0.0000001)) WHERE id = layer_id;
          ELSE
            UPDATE layers SET geom = ST_Envelope(ST_Collect(geo, box)) WHERE id = layer_id;
          END IF;
          RETURN NULL;
        END;
    $$;


ALTER FUNCTION public.update_layer_bounds_from_object_data() OWNER TO tom;

SET default_tablespace = '';

SET default_with_oids = false;


CREATE TABLE categories (
    id integer NOT NULL,
    name text NOT NULL,
    title text NOT NULL,
    CONSTRAINT constraint_name_alphanumeric CHECK ((name ~ similar_escape('([_A-Za-z0-9]+)|([_A-Za-z0-9]+)(.[__A-Za-z0-9]+)*'::text, NULL::text)))
);


ALTER TABLE public.categories OWNER TO tom;


CREATE SEQUENCE categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.categories_id_seq OWNER TO tom;


ALTER SEQUENCE categories_id_seq OWNED BY categories.id;


CREATE TABLE fields (
    layer_id integer NOT NULL,
    name text NOT NULL,
    type text,
    unit text,
    lang text,
    "equivalentProperty" text,
    description text,
    CONSTRAINT constraint_name_alphanumeric CHECK ((name ~ similar_escape('([_A-Za-z0-9]+)|([_A-Za-z0-9]+)(.[__A-Za-z0-9]+)*'::text, NULL::text)))
);


ALTER TABLE public.fields OWNER TO tom;


CREATE TABLE layers (
    id integer NOT NULL,
    owner_id integer NOT NULL,
    category_id integer NOT NULL,
    depends_on_layer_id integer,
    name text NOT NULL,
    title text,
    description text,
    data_sources text[],
    licence text,
    authoritative boolean DEFAULT false,
    context json,
    update_rate integer,
    webservice_url text,
    imported_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    geom geometry(Geometry,4326),
    sample_url text,
    CONSTRAINT constraint_geom_no_geometrycollection CHECK ((geometrytype(geom) <> 'GEOMETRYCOLLECTION'::text)),
    CONSTRAINT constraint_name_alphanumeric CHECK ((name ~ similar_escape('([_A-Za-z0-9]+)|([_A-Za-z0-9]+)(.[__A-Za-z0-9]+)*'::text, NULL::text)))
);


ALTER TABLE public.layers OWNER TO tom;


CREATE SEQUENCE layers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.layers_id_seq OWNER TO tom;


ALTER SEQUENCE layers_id_seq OWNED BY layers.id;


CREATE TABLE object_data (
    id integer NOT NULL,
    object_id bigint NOT NULL,
    layer_id integer NOT NULL,
    data hstore,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.object_data OWNER TO tom;


CREATE SEQUENCE object_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.object_data_id_seq OWNER TO tom;


ALTER SEQUENCE object_data_id_seq OWNED BY object_data.id;


CREATE TABLE objects (
    id integer NOT NULL,
    layer_id integer NOT NULL,
    cdk_id text NOT NULL,
    title text,
    members bigint[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    geom geometry(Geometry,4326),
    CONSTRAINT constraint_geom_no_geometrycollection CHECK ((geometrytype(geom) <> 'GEOMETRYCOLLECTION'::text)),
    CONSTRAINT constraint_name_alphanumeric CHECK ((cdk_id ~ similar_escape('([_A-Za-z0-9]+)|([_A-Za-z0-9]+)(.[__A-Za-z0-9]+)*'::text, NULL::text)))
);


ALTER TABLE public.objects OWNER TO tom;


CREATE SEQUENCE objects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.objects_id_seq OWNER TO tom;


ALTER SEQUENCE objects_id_seq OWNED BY objects.id;


CREATE TABLE owners (
    id integer NOT NULL,
    name text NOT NULL,
    fullname text NOT NULL,
    email text NOT NULL,
    admin boolean DEFAULT false,
    website text,
    organization text,
    domains text[],
    password text,
    salt text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT constraint_name_alphanumeric CHECK ((name ~ similar_escape('([_A-Za-z0-9]+)|([_A-Za-z0-9]+)(.[__A-Za-z0-9]+)*'::text, NULL::text)))
);


ALTER TABLE public.owners OWNER TO tom;


CREATE SEQUENCE owners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.owners_id_seq OWNER TO tom;


ALTER SEQUENCE owners_id_seq OWNED BY owners.id;


CREATE TABLE schema_info (
    version integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.schema_info OWNER TO tom;


ALTER TABLE ONLY categories ALTER COLUMN id SET DEFAULT nextval('categories_id_seq'::regclass);


ALTER TABLE ONLY layers ALTER COLUMN id SET DEFAULT nextval('layers_id_seq'::regclass);


ALTER TABLE ONLY object_data ALTER COLUMN id SET DEFAULT nextval('object_data_id_seq'::regclass);


ALTER TABLE ONLY objects ALTER COLUMN id SET DEFAULT nextval('objects_id_seq'::regclass);


ALTER TABLE ONLY owners ALTER COLUMN id SET DEFAULT nextval('owners_id_seq'::regclass);


COPY categories (id, name, title) FROM stdin;
0	none	None
1	natural	Natural
2	cultural	Cultural
3	civic	Civic
4	tourism	Tourism
5	mobility	Mobility
6	administrative	Administrative
7	environment	Environment
8	health	Health
9	education	Education
10	security	Security
11	commercial	Commercial
\.


SELECT pg_catalog.setval('categories_id_seq', 11, true);


COPY fields (layer_id, name, type, unit, lang, "equivalentProperty", description) FROM stdin;
\.


COPY layers (id, owner_id, category_id, depends_on_layer_id, name, title, description, data_sources, licence, authoritative, context, update_rate, webservice_url, imported_at, created_at, geom, sample_url) FROM stdin;
\.


SELECT pg_catalog.setval('layers_id_seq', 1, false);


COPY object_data (id, object_id, layer_id, data, created_at, updated_at) FROM stdin;
\.


SELECT pg_catalog.setval('object_data_id_seq', 1, false);


COPY objects (id, layer_id, cdk_id, title, members, created_at, updated_at, geom) FROM stdin;
\.


SELECT pg_catalog.setval('objects_id_seq', 1, false);


COPY owners (id, name, fullname, email, admin, website, organization, domains, password, salt, created_at) FROM stdin;
0	citysdk	CitySDK	citysdk@waag.org	t	\N	CitySDK LD	\N	\N	\N	2014-06-10 13:41:02.088097+02
\.


--
-- Name: owners_id_seq; Type: SEQUENCE SET; Schema: public; Owner: tom
--

SELECT pg_catalog.setval('owners_id_seq', 1, true);


--
-- Data for Name: schema_info; Type: TABLE DATA; Schema: public; Owner: tom
--

COPY schema_info (version) FROM stdin;
5
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: tom
--

COPY spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Name: categories_pkey; Type: CONSTRAINT; Schema: public; Owner: tom; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (layer_id, name);


ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_name_key UNIQUE (name);


ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_pkey PRIMARY KEY (id);


ALTER TABLE ONLY object_data
    ADD CONSTRAINT object_data_layer_id_object_id_key UNIQUE (layer_id, object_id);


ALTER TABLE ONLY object_data
    ADD CONSTRAINT object_data_pkey PRIMARY KEY (id);


ALTER TABLE ONLY objects
    ADD CONSTRAINT objects_cdk_id_key UNIQUE (cdk_id);


ALTER TABLE ONLY objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


ALTER TABLE ONLY owners
    ADD CONSTRAINT owners_email_key UNIQUE (email);


ALTER TABLE ONLY owners
    ADD CONSTRAINT owners_name_key UNIQUE (name);


ALTER TABLE ONLY owners
    ADD CONSTRAINT owners_pkey PRIMARY KEY (id);


CREATE INDEX layers_geom_idx ON layers USING gist (geom);


CREATE INDEX layers_title_index ON layers USING gin (to_tsvector('simple'::regconfig, COALESCE(title, ''::text)));


CREATE INDEX object_data_data_index ON object_data USING btree (data);


CREATE INDEX object_data_layer_id_index ON object_data USING btree (layer_id);


CREATE INDEX object_data_object_id_index ON object_data USING btree (object_id);


CREATE INDEX objects_geom_idx ON objects USING gist (geom);


CREATE INDEX objects_layer_id_index ON objects USING btree (layer_id);


CREATE INDEX objects_lower__title___index ON objects USING btree (lower(title));


CREATE INDEX objects_members_index ON objects USING gin (members);


CREATE INDEX objects_title_index ON objects USING gin (to_tsvector('simple'::regconfig, COALESCE(title, ''::text)));


CREATE TRIGGER object_data_inserted AFTER INSERT ON object_data FOR EACH ROW EXECUTE PROCEDURE update_layer_bounds_from_object_data();


CREATE TRIGGER object_inserted AFTER INSERT OR UPDATE ON objects FOR EACH ROW EXECUTE PROCEDURE update_layer_bounds_from_object();


ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layers(id) ON DELETE CASCADE;


ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_category_id_fkey FOREIGN KEY (category_id) REFERENCES categories(id);


ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_depends_on_layer_id_fkey FOREIGN KEY (depends_on_layer_id) REFERENCES layers(id) ON DELETE CASCADE;


ALTER TABLE ONLY layers
    ADD CONSTRAINT layers_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES owners(id) ON DELETE CASCADE;


ALTER TABLE ONLY object_data
    ADD CONSTRAINT object_data_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layers(id) ON DELETE CASCADE;


ALTER TABLE ONLY object_data
    ADD CONSTRAINT object_data_object_id_fkey FOREIGN KEY (object_id) REFERENCES objects(id) ON DELETE CASCADE;


ALTER TABLE ONLY objects
    ADD CONSTRAINT objects_layer_id_fkey FOREIGN KEY (layer_id) REFERENCES layers(id) ON DELETE CASCADE;


REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM tom;
GRANT ALL ON SCHEMA public TO tom;
GRANT ALL ON SCHEMA public TO PUBLIC;
