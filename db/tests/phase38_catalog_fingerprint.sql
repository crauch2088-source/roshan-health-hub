-- Canonical SHA-256 catalog fingerprint shared by live read-only inspection and PostgreSQL 17 CI.
WITH
table_columns AS (
 SELECT concat_ws('|',table_schema,table_name,column_name,data_type,udt_name,is_nullable) AS row_text
 FROM information_schema.columns WHERE table_schema IN ('public','private')
),
constraints AS (
 SELECT concat_ws('|',n.nspname,c.relname,con.conname,con.contype::text) AS row_text
 FROM pg_constraint con JOIN pg_class c ON c.oid=con.conrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','private')
),
indexes AS (
 SELECT concat_ws('|',schemaname,tablename,indexname) AS row_text
 FROM pg_indexes WHERE schemaname IN ('public','private')
),
functions_security AS (
 SELECT concat_ws('|',n.nspname,p.proname,pg_get_function_identity_arguments(p.oid),
                  p.prosecdef::text,coalesce(array_to_string(p.proconfig,','),'')) AS row_text
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname IN ('public','private') AND p.prokind IN ('f','p','w')
),
triggers AS (
 SELECT concat_ws('|',n.nspname,c.relname,t.tgname,p.proname) AS row_text
 FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
 JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_proc p ON p.oid=t.tgfoid
 WHERE n.nspname IN ('public','private') AND NOT t.tgisinternal
),
rls_policies AS (
 SELECT concat_ws('|',schemaname,tablename,policyname,permissive,cmd,array_to_string(roles,',')) AS row_text
 FROM pg_policies WHERE schemaname IN ('public','private')
),
clinical_financial_privileges AS (
 SELECT DISTINCT concat_ws('|',table_schema,table_name,grantee,privilege_type) AS row_text
 FROM information_schema.table_privileges
 WHERE table_schema IN ('public','private')
   AND grantee IN ('authenticated','anon')
   AND table_name ~* '(patient|visit|clinical|medical|lab|prescription|pharmacy|invoice|billing|payment|account|receipt|certificate|queue|encounter|diagnos|procedure|drug|medication|order)'
),
all_categories AS (
 SELECT 'tables_columns' AS category,row_text FROM table_columns
 UNION ALL SELECT 'constraints',row_text FROM constraints
 UNION ALL SELECT 'indexes',row_text FROM indexes
 UNION ALL SELECT 'functions_security',row_text FROM functions_security
 UNION ALL SELECT 'triggers',row_text FROM triggers
 UNION ALL SELECT 'rls_policies',row_text FROM rls_policies
 UNION ALL SELECT 'clinical_financial_privileges',row_text FROM clinical_financial_privileges
),
category_names(category) AS (
 VALUES ('tables_columns'),('constraints'),('indexes'),('functions_security'),('triggers'),('rls_policies'),('clinical_financial_privileges')
),
aggregated AS (
 SELECT n.category,count(a.row_text)::integer AS object_count,
        string_agg(a.row_text,E'\n' ORDER BY a.row_text) AS canonical_rows
 FROM category_names n LEFT JOIN all_categories a ON a.category=n.category
 GROUP BY n.category
)
SELECT jsonb_object_agg(category,jsonb_build_object(
  'count',object_count,
  'sha256',encode(sha256(convert_to(coalesce(canonical_rows,''),'UTF8')),'hex')
))::text
FROM aggregated;
