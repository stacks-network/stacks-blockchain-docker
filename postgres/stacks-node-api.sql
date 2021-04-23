CREATE ROLE stacks LOGIN PASSWORD 'postgres';
--
-- stacks_node_api db setup
--
create database stacks_mainnet;
create database stacks_testnet;
create database stacks_mocknet;
revoke all on database stacks_mainnet from public;
revoke all on database stacks_testnet from public;
revoke all on database stacks_mocknet from public;
grant all privileges on database stacks_mainnet to postgres;
grant all privileges on database stacks_testnet to postgres;
grant all privileges on database stacks_mocknet to postgres;
grant connect, temp on database stacks_mainnet to stacks;
grant connect, temp on database stacks_testnet to stacks;
grant connect, temp on database stacks_mocknet to stacks;

--
-- stacks_node_api permissions
--
\c stacks_mainnet;
DROP SCHEMA IF EXISTS stacks_node_api CASCADE;
grant stacks to postgres;
alter database stacks_mainnet set default_transaction_read_only = off;
alter database stacks_mainnet owner to postgres;
create schema if not exists stacks_node_api authorization stacks;
alter database stacks_mainnet set search_path TO stacks_node_api,public;
alter user stacks set search_path TO stacks_node_api,public;
revoke all on schema public from public;
revoke all on schema stacks_node_api from public;
grant connect, temp on database stacks_mainnet to stacks;
grant all on schema stacks_node_api to postgres;
grant create, usage on schema stacks_node_api to stacks;

\c stacks_testnet;
DROP SCHEMA IF EXISTS stacks_node_api CASCADE;
grant stacks to postgres;
alter database stacks_testnet set default_transaction_read_only = off;
alter database stacks_testnet owner to postgres;
create schema if not exists stacks_node_api authorization stacks;
alter database stacks_testnet set search_path TO stacks_node_api,public;
alter user stacks set search_path TO stacks_node_api,public;
revoke all on schema public from public;
revoke all on schema stacks_node_api from public;
grant connect, temp on database stacks_testnet to stacks;
grant all on schema stacks_node_api to postgres;
grant create, usage on schema stacks_node_api to stacks;

\c stacks_mocknet;
DROP SCHEMA IF EXISTS stacks_node_api CASCADE;
grant stacks to postgres;
alter database stacks_mocknet set default_transaction_read_only = off;
alter database stacks_mocknet owner to postgres;
create schema if not exists stacks_node_api authorization stacks;
alter database stacks_mocknet set search_path TO stacks_node_api,public;
alter user stacks set search_path TO stacks_node_api,public;
revoke all on schema public from public;
revoke all on schema stacks_node_api from public;
grant connect, temp on database stacks_mocknet to stacks;
grant all on schema stacks_node_api to postgres;
grant create, usage on schema stacks_node_api to stacks;

