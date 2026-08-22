{% macro generate_schema_name(custom_schema_name, node) -%}

    {#-
        Schema custom utilise tel quel (silver, gold) ; sinon le schema du profil.
        Nommage sans prefixe par la cible (le repo n'a qu'un seul target).
    -#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
