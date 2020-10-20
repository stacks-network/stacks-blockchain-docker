create role sidecar_rw with LOGIN ENCRYPTED PASSWORD 'postgres';
--
-- sidecar db setup
--
create database stacks_node_api;
revoke all on database stacks_node_api from public;
grant all privileges on database stacks_node_api to postgres;
grant connect, temp on database stacks_node_api to sidecar_rw;
--
-- sidecar permissions
--
\c stacks_node_api;
DROP SCHEMA IF EXISTS sidecar CASCADE;
grant sidecar_rw to postgres;
alter database stacks_node_api set default_transaction_read_only = off;
alter database stacks_node_api owner to postgres;
create schema if not exists sidecar authorization sidecar_rw;
alter database stacks_node_api set search_path TO sidecar,public;
alter user sidecar_rw set search_path TO sidecar,public;
revoke all on schema public from public;
revoke all on schema sidecar from public;
grant connect, temp on database stacks_node_api to sidecar_rw;
grant all on schema sidecar to postgres;
grant create, usage on schema sidecar to sidecar_rw;
