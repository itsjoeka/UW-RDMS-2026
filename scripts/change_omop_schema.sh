# Create a modified version with YOUR schema name
sed 's/@cdmDatabaseSchema/omop/g' OMOPCDM_postgresql_5.4_ddl.sql > omop_ddl_modified.sql

# Check it worked (should show "CREATE TABLE omop.PERSON")
head -20 omop_ddl_modified.sql
