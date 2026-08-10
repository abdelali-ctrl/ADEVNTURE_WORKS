-- =====================================================================
-- 01_file_formats.sql  --  Formats de fichier pour les CSV AdventureWorks
-- Les fichiers sont tab-delimited, SANS en-tete, encodages mixtes UTF-8/UTF-16.
-- =====================================================================

use role dbt_role;
use warehouse compute_wh;

create database if not exists aw_source;
create schema if not exists aw_source.raw;
use schema aw_source.raw;

-- Format UTF-8 (majorite des tables)
create or replace file format ff_aw_tsv_utf8
    type = csv
    field_delimiter = '\t'          -- tabulation, malgre l'extension .csv
    record_delimiter = '\n'
    skip_header = 0                  -- aucune ligne d'en-tete
    field_optionally_enclosed_by = none
    escape_unenclosed_field = none
    empty_field_as_null = true
    null_if = ('', 'NULL')
    encoding = 'UTF8'
    error_on_column_count_mismatch = true;   -- detecte les decalages de colonnes

-- Format UTF-16 (fichiers charges en 'widechar' par instawdb.sql)
create or replace file format ff_aw_tsv_utf16
    type = csv
    field_delimiter = '\t'
    record_delimiter = '\n'
    skip_header = 0
    field_optionally_enclosed_by = none
    escape_unenclosed_field = none
    empty_field_as_null = true
    null_if = ('', 'NULL')
    encoding = 'UTF-16'
    error_on_column_count_mismatch = true;

show file formats in schema aw_source.raw;
