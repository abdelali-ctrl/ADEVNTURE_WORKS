{% macro generate_schema_name(custom_schema_name, node) -%}

    {#-
        Nommage des schemas selon la cible :
        - pas de schema custom  -> schema du profil (target.schema)
        - cible 'ci'            -> suffixe _ci pour ISOLER les builds de PR
                                   (silver -> silver_ci, gold -> gold_ci)
        - sinon (dev/prod)      -> le schema custom tel quel (silver, gold)
        Sans ce suffixe, la CI ecraserait les schemas de dev.
    -#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'ci' -%}
        {{ custom_schema_name | trim }}_ci
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
