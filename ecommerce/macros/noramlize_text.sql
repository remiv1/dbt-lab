{% macro normalize_text(column_name, case='lower') %}

    {% if case == 'upper' %}

        UPPER(TRIM({{ column_name }}))

    {% else %}

        LOWER(TRIM({{ column_name }}))

    {% endif %}

{% endmacro %}