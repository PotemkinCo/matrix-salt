-- The official PostgreSQL image runs this only when it initializes an empty data directory.
-- Passwords are provided by the container environment and quoted by psql before SQL execution.
\getenv synapse_password SYNAPSE_DB_PASSWORD
\getenv mas_password MAS_DB_PASSWORD

CREATE ROLE synapse LOGIN PASSWORD :'synapse_password';
CREATE DATABASE synapse OWNER synapse LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
CREATE ROLE mas LOGIN PASSWORD :'mas_password';
CREATE DATABASE mas OWNER mas LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
