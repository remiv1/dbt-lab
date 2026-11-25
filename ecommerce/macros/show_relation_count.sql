{% macro show_relation_count(relation_name) %}

    {% set query %}
        SELECT COUNT(*) AS row_count
        FROM {{ relation_name }}
    {% endset %}

    {% set results = run_query(query) %}

    {% if results is not none %}
        {% set row_count = results.columns[0].values()[0] %}
        {{ log(relation_name ~ ' : ' ~ row_count ~ ' lignes', info=true) }}
    {% endif %}

{% endmacro %}