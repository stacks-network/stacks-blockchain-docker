CREATE ROLE stacks LOGIN PASSWORD 'postgres';
--
-- stacks_node_api db setup
--
create database stacks_blockchain;
revoke all on database stacks_blockchain from public;
grant all privileges on database stacks_blockchain to postgres;
grant connect, temp on database stacks_blockchain to stacks;

--
-- stacks_node_api permissions
--
\c stacks_blockchain;
DROP SCHEMA IF EXISTS stacks_node_api CASCADE;
grant stacks to postgres;
alter database stacks_blockchain set default_transaction_read_only = off;
alter database stacks_blockchain owner to postgres;
create schema if not exists stacks_node_api authorization stacks;
alter database stacks_blockchain set search_path TO stacks_node_api,public;
alter user stacks set search_path TO stacks_node_api,public;
revoke all on schema public from public;
revoke all on schema stacks_node_api from public;
grant connect, temp on database stacks_blockchain to stacks;
grant all on schema stacks_node_api to postgres;
grant create, usage on schema stacks_node_api to stacks;

