#!/usr/bin/env bash

set -euo pipefail

RAW_SCHEMA="integration_raw"
STAGING_SCHEMA="dbt_integration_staging"
MARTS_SCHEMA="dbt_integration_marts"

DBT_ARGS=(
    --target integration
    --vars "{raw_schema: $RAW_SCHEMA}"
)

run_sql() {
    dbt run-operation --sql "$1" "${DBT_ARGS[@]}"
}

run_sql_file() {
    local sql
    sql="$(<"$1")"
    run_sql "$sql"
}

query_preview() {
    dbt show \
        --inline "$1" \
        --output json \
        --log-format json \
        "${DBT_ARGS[@]}" \
        | jq -er 'select(.info.name == "ShowNode") | .data.preview'
}

query_scalar() {
    local preview
    preview="$(query_preview "$1")"
    jq -er --arg key "$2" '.[0][$key]' <<< "$preview"
}

cleanup() {
    echo
    echo "== Cleanup =="

    run_sql "DROP SCHEMA IF EXISTS ${RAW_SCHEMA} CASCADE" || true
    run_sql "DROP SCHEMA IF EXISTS ${STAGING_SCHEMA} CASCADE" || true
    run_sql "DROP SCHEMA IF EXISTS ${MARTS_SCHEMA} CASCADE" || true
}

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

trap cleanup EXIT

command -v jq >/dev/null \
    || fail "jq is required to parse dbt show JSON output"


echo "========================================"
echo "Integration test: orders_incremental"
echo "========================================"


echo
echo "== 1. Clean test environment =="

run_sql "DROP SCHEMA IF EXISTS ${RAW_SCHEMA} CASCADE"
run_sql "DROP SCHEMA IF EXISTS ${STAGING_SCHEMA} CASCADE"
run_sql "DROP SCHEMA IF EXISTS ${MARTS_SCHEMA} CASCADE"


echo
echo "== 2. Load fixture N =="

run_sql_file integration_tests/fixtures/orders_n.sql


echo
echo "== 3. Initial build =="

dbt run \
    --select stg_orders orders_incremental \
    "${DBT_ARGS[@]}"


echo
echo "== 4. Assertions for state N =="

count_n="$(query_scalar "
    SELECT COUNT(*) AS row_count
    FROM ${MARTS_SCHEMA}.orders_incremental
    WHERE order_id IN (9901, 9902)
" row_count)"

[[ "$count_n" == "2" ]] \
    || fail "Expected 2 rows at state N, got $count_n"


status_9902="$(query_scalar "
    SELECT status
    FROM ${MARTS_SCHEMA}.orders_incremental
    WHERE order_id = 9902
" status)"

[[ "$status_9902" == "pending" ]] \
    || fail "Expected 9902 to be pending at state N"


hash_9902_n="$(query_scalar "
    SELECT row_hash
    FROM ${MARTS_SCHEMA}.orders_incremental
    WHERE order_id = 9902
" row_hash)"

[[ "$hash_9902_n" == "hash_9902_v1" ]] \
    || fail "Unexpected hash for 9902 at state N"


echo "PASS: state N is correct"


echo
echo "== 5. Load fixture N+1 =="

run_sql_file integration_tests/fixtures/orders_n_plus_1.sql


echo
echo "== 6. Incremental build =="

dbt run \
    --select stg_orders orders_incremental \
    "${DBT_ARGS[@]}"


echo
echo "== 7. Assertions for state N+1 =="

count_n1="$(query_scalar "
    SELECT COUNT(*) AS row_count
    FROM ${MARTS_SCHEMA}.orders_incremental
    WHERE order_id IN (9901, 9902, 9903)
" row_count)"

[[ "$count_n1" == "3" ]] \
    || fail "Expected 3 rows at state N+1, got $count_n1"


duplicate_count="$(query_scalar "
    SELECT COUNT(*) AS duplicate_count
    FROM (
        SELECT order_id
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id IN (9901, 9902, 9903)
        GROUP BY order_id
        HAVING COUNT(*) <> 1
    ) AS duplicates
" duplicate_count)"

[[ "$duplicate_count" == "0" ]] \
    || fail "Duplicate order_id detected"


status_9902="$(query_scalar "
    SELECT status
    FROM ${MARTS_SCHEMA}.orders_incremental
    WHERE order_id = 9902
" status)"

[[ "$status_9902" == "completed" ]] \
    || fail "9902 was not updated to completed"


hash_9902_n1="$(query_scalar "
    SELECT row_hash
    FROM ${MARTS_SCHEMA}.orders_incremental
    WHERE order_id = 9902
" row_hash)"

[[ "$hash_9902_n1" == "hash_9902_v2" ]] \
    || fail "9902 did not receive its new hash"


[[ "$hash_9902_n" != "$hash_9902_n1" ]] \
    || fail "9902 hash did not change"


status_9903="$(query_scalar "
    SELECT status
    FROM ${MARTS_SCHEMA}.orders_incremental
    WHERE order_id = 9903
" status)"

[[ "$status_9903" == "completed" ]] \
    || fail "9903 was not inserted"


echo "PASS: UPDATE and INSERT behaved correctly"


echo
echo "== 8. Capture state before idempotence test =="

state_before="$(query_scalar "
    SELECT md5(
        string_agg(
            CAST(order_id AS VARCHAR) || '|' ||
            CAST(customer_id AS VARCHAR) || '|' ||
            CAST(order_date AS VARCHAR) || '|' ||
            CAST(amount AS VARCHAR) || '|' ||
            status || '|' ||
            row_hash,
            ',' ORDER BY order_id
        )
    ) AS state_hash
    FROM ${MARTS_SCHEMA}.orders_incremental
" state_hash)"


echo
echo "== 9. Run again without source changes =="

dbt run \
    --select stg_orders orders_incremental \
    "${DBT_ARGS[@]}"


state_after="$(query_scalar "
    SELECT md5(
        string_agg(
            CAST(order_id AS VARCHAR) || '|' ||
            CAST(customer_id AS VARCHAR) || '|' ||
            CAST(order_date AS VARCHAR) || '|' ||
            CAST(amount AS VARCHAR) || '|' ||
            status || '|' ||
            row_hash,
            ',' ORDER BY order_id
        )
    ) AS state_hash
    FROM ${MARTS_SCHEMA}.orders_incremental
" state_hash)"


[[ "$state_before" == "$state_after" ]] \
    || fail "Incremental model is not idempotent"


echo "PASS: model is idempotent"

echo
echo "========================================"
echo "ALL INTEGRATION TESTS PASSED"
echo "========================================"