{% test is_null(model, column_name) %}

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL

{% endtest %}