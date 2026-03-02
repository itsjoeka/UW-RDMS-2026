# Create a new modified version with larger VARCHAR fields
sed 's/varchar(50)/varchar(255)/g' omop_ddl_modified.sql > omop_ddl_final.sql
sed -i 's/varchar(20)/varchar(100)/g' omop_ddl_final.sql
