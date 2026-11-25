#!/usr/bin/env bash

set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-ecommerce}"
DB_USER="${DB_USER:-dbt}"

RAW_SCHEMA="integration_raw"
STAGING_SCHEMA="dbt_integration_staging"
MARTS_SCHEMA="dbt_integration_marts"

export PGPASSWORD="${PGPASSWORD:?PGPASSWORD must be defined}"

PSQL=(
    psql
    -X
    -v ON_ERROR_STOP=1
    -h "$DB_HOST"
    -p "$DB_PORT"
    -U "$DB_USER"
    -d "$DB_NAME"
)

DBT_ARGS=(
    --target integration
    --vars "{raw_schema: $RAW_SCHEMA}"
)

cleanup() {
    echo
    echo "== Cleanup =="

    "${PSQL[@]}" <<SQL
DROP SCHEMA IF EXISTS ${RAW_SCHEMA} CASCADE;
DROP SCHEMA IF EXISTS ${STAGING_SCHEMA} CASCADE;
DROP SCHEMA IF EXISTS ${MARTS_SCHEMA} CASCADE;
SQL
}

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

trap cleanup EXIT


echo "========================================"
echo "Integration test: orders_incremental"
echo "========================================"


echo
echo "== 1. Clean test environment =="

"${PSQL[@]}" <<SQL
DROP SCHEMA IF EXISTS ${RAW_SCHEMA} CASCADE;
DROP SCHEMA IF EXISTS ${STAGING_SCHEMA} CASCADE;
DROP SCHEMA IF EXISTS ${MARTS_SCHEMA} CASCADE;
SQL


echo
echo "== 2. Load fixture N =="

"${PSQL[@]}" \
    -f integration_tests/fixtures/orders_n.sql


echo
echo "== 3. Initial build =="

dbt run \
    --select stg_orders orders_incremental \
    "${DBT_ARGS[@]}"


echo
echo "== 4. Assertions for state N =="

count_n="$(
    "${PSQL[@]}" -Atc "
        SELECT COUNT(*)
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id IN (9901, 9902);
    "
)"

[[ "$count_n" == "2" ]] \
    || fail "Expected 2 rows at state N, got $count_n"


status_9902="$(
    "${PSQL[@]}" -Atc "
        SELECT status
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id = 9902;
    "
)"

[[ "$status_9902" == "pending" ]] \
    || fail "Expected 9902 to be pending at state N"


hash_9902_n="$(
    "${PSQL[@]}" -Atc "
        SELECT row_hash
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id = 9902;
    "
)"

[[ "$hash_9902_n" == "hash_9902_v1" ]] \
    || fail "Unexpected hash for 9902 at state N"


echo "PASS: state N is correct"


echo
echo "== 5. Load fixture N+1 =="

"${PSQL[@]}" \
    -f integration_tests/fixtures/orders_n_plus_1.sql


echo
echo "== 6. Incremental build =="

dbt run \
    --select stg_orders orders_incremental \
    "${DBT_ARGS[@]}"


echo
echo "== 7. Assertions for state N+1 =="

count_n1="$(
    "${PSQL[@]}" -Atc "
        SELECT COUNT(*)
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id IN (9901, 9902, 9903);
    "
)"

[[ "$count_n1" == "3" ]] \
    || fail "Expected 3 rows at state N+1, got $count_n1"


duplicate_count="$(
    "${PSQL[@]}" -Atc "
        SELECT COUNT(*)
        FROM (
            SELECT order_id
            FROM ${MARTS_SCHEMA}.orders_incremental
            WHERE order_id IN (9901, 9902, 9903)
            GROUP BY order_id
            HAVING COUNT(*) <> 1
        ) AS duplicates;
    "
)"

[[ "$duplicate_count" == "0" ]] \
    || fail "Duplicate order_id detected"


status_9902="$(
    "${PSQL[@]}" -Atc "
        SELECT status
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id = 9902;
    "
)"

[[ "$status_9902" == "completed" ]] \
    || fail "9902 was not updated to completed"


hash_9902_n1="$(
    "${PSQL[@]}" -Atc "
        SELECT row_hash
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id = 9902;
    "
)"

[[ "$hash_9902_n1" == "hash_9902_v2" ]] \
    || fail "9902 did not receive its new hash"


[[ "$hash_9902_n" != "$hash_9902_n1" ]] \
    || fail "9902 hash did not change"


status_9903="$(
    "${PSQL[@]}" -Atc "
        SELECT status
        FROM ${MARTS_SCHEMA}.orders_incremental
        WHERE order_id = 9903;
    "
)"

[[ "$status_9903" == "completed" ]] \
    || fail "9903 was not inserted"


echo "PASS: UPDATE and INSERT behaved correctly"


echo
echo "== 8. Capture state before idempotence test =="

state_before="$(
    "${PSQL[@]}" -Atc "
        SELECT md5(
            string_agg(
                order_id::text || '|' ||
                customer_id::text || '|' ||
                order_date::text || '|' ||
                amount::text || '|' ||
                status || '|' ||
                row_hash,
                ',' ORDER BY order_id
            )
        )
        FROM ${MARTS_SCHEMA}.orders_incremental;
    "
)"


echo
echo "== 9. Run again without source changes =="

dbt run \
    --select stg_orders orders_incremental \
    "${DBT_ARGS[@]}"


state_after="$(
    "${PSQL[@]}" -Atc "
        SELECT md5(
            string_agg(
                order_id::text || '|' ||
                customer_id::text || '|' ||
                order_date::text || '|' ||
                amount::text || '|' ||
                status || '|' ||
                row_hash,
                ',' ORDER BY order_id
            )
        )
        FROM ${MARTS_SCHEMA}.orders_incremental;
    "
)"


[[ "$state_before" == "$state_after" ]] \
    || fail "Incremental model is not idempotent"


echo "PASS: model is idempotent"

echo
echo "========================================"
echo "ALL INTEGRATION TESTS PASSED"
echo "========================================"