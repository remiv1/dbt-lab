{% macro normalize_text(column_name, case='lower', remove_spaces=false) %}

    {% if remove_spaces %}
        {% set expression %}
            REGEXP_REPLACE({{ column_name }}, '\s+', '', 'g')
        {% endset %}
    {% else %}
        {% set expression %}
            {{ column_name }}
        {% endset %}
    {% endif %}

    {% if case == 'upper' %}
        UPPER(TRIM({{ expression }}))
    {% else %}
        LOWER(TRIM({{ expression }}))
    {% endif %}

{% endmacro %}