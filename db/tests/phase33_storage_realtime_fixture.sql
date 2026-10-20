-- CI-only stand-ins for Supabase platform schemas; never use in production.
CREATE SCHEMA IF NOT EXISTS storage; CREATE SCHEMA IF NOT EXISTS realtime;
CREATE TABLE IF NOT EXISTS storage.buckets(id text PRIMARY KEY,name text UNIQUE NOT NULL,public boolean NOT NULL DEFAULT false,file_size_limit bigint,allowed_mime_types text[]);
CREATE TABLE IF NOT EXISTS storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text NOT NULL REFERENCES storage.buckets(id),name text NOT NULL,owner_id uuid,metadata jsonb NOT NULL DEFAULT '{}'::jsonb);
CREATE TABLE IF NOT EXISTS realtime.messages(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),topic text NOT NULL,payload jsonb NOT NULL DEFAULT '{}'::jsonb);
CREATE OR REPLACE FUNCTION realtime.topic() RETURNS text LANGUAGE sql STABLE AS $topic$ SELECT NULLIF(current_setting('realtime.topic',true),'') $topic$;
CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $role$ SELECT COALESCE(NULLIF(current_setting('request.jwt.claim.role',true),''),current_user) $role$;
GRANT USAGE ON SCHEMA storage,realtime TO authenticated; GRANT SELECT ON storage.buckets,storage.objects,realtime.messages TO authenticated;
GRANT USAGE ON SCHEMA auth,storage,realtime TO service_role;
GRANT ALL ON auth.users,storage.buckets,storage.objects,realtime.messages TO service_role;
