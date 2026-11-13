# Daily Grind Skate Co. (DGDB) Oracle schema deployment

**Status:** deployed and documented. Deployment details below are recorded as verified for this lab.
**Target:** Oracle AI Database 26ai Free, application PDB `FREEPDB1`.
**DDL:** [`schema/dgdb/001_core_schema.sql`](../schema/dgdb/001_core_schema.sql)
**Seeds:** [`schema/dgdb/002_seed_catalogue.sql`](../schema/dgdb/002_seed_catalogue.sql) and [`schema/dgdb/003_seed_transactions.sql`](../schema/dgdb/003_seed_transactions.sql).

## Deployment record

- **PDB:** `FREEPDB1`.
- **Tablespace:** `DGDB_DATA`, initially 100 MB, configured to autoextend up to 1 GB.
- **Persistent datafile:** `/opt/oracle/oradata/FREE/FREEPDB1/dgdb_data01.dbf`.
- **Schema owner:** `DGDB`, with a 250 MB quota on `DGDB_DATA`.
- **Grants:** `CREATE SESSION`, `CREATE TABLE`, and `CREATE SEQUENCE`.
- **Objects verified:** eight tables and two explicit indexes from this schema; the explicit indexes support reservation expiry lookup and product stock-movement history. Constraint indexes created by primary/unique constraints are additional implicit indexes.
- **Constraint verification:** the stock movement reason constraint `STOCK_MOVEMENTS_REASON_CK` was validated, using `REGEXP_LIKE(reason, '[^[:space:]]')` to reject whitespace-only reasons.

The initial deployment attempt returned `ORA-01031: insufficient privileges`. Investigation found the privilege context was `CDB$ROOT` rather than the target `FREEPDB1`; the required PDB-level privilege context was then checked and the deployment was retried in `FREEPDB1`. The deployment retry completed and the object counts and reason constraint were verified. No passwords, secrets, or credential material are recorded here.

The deployment record describes the database outcome. The DDL remains a deployment script, not a migration or rerunnable installer: its `CREATE TABLE` and `CREATE INDEX` statements are intentionally non-idempotent. Do not rerun it against the already deployed schema. Both seed scripts are also intended to run once.

On 13 November 2026, the transaction seed was executed as `DGDB` in `FREEPDB1` after the catalogue seed. Oracle verification reported 12 orders (6 `FULFILLED`, 2 `PAID`, 2 `PENDING`, 1 `CANCELLED`, 1 `EXPIRED`), 9 payments (8 `SUCCEEDED`, 1 `FAILED`), and no discrepancies in order totals, physical stock, or reserved stock reconciliation. These counts describe the recorded seed result, not an independently repeated database check in this document review.

## Scope and data model

The schema models one warehouse, one SKU per product, AUD-only commerce, and temporary checkout reservations. It creates eight tables: `PRODUCTS`, `CUSTOMERS`, `INVENTORY`, `ORDERS`, `ORDER_ITEMS`, `RESERVATIONS`, `PAYMENTS`, and `STOCK_MOVEMENTS`. Each product has one inventory row, enforced by `INVENTORY.PRODUCT_ID` being its primary key. SKU uniqueness enforces one SKU per product. The schema intentionally does not model multiple warehouses, tax rules, shipping addresses, promotions, returns workflow, or gateway events.

Prices are stored as `NUMBER(...,2)` AUD amounts. Product price is copied to each order item at checkout so later catalogue price changes do not alter the order. Order subtotal and total are stored snapshots; application transaction logic must calculate them from order items and any approved charges. The deployed schema and seeds have no tax or shipping calculation.

All event and audit timestamps use `TIMESTAMP(6) WITH TIME ZONE`, defaulting to `SYSTIMESTAMP` where appropriate. `updated_at` defaults on insert only: every update path must set it explicitly. Store instants with their time-zone offset and render in the chosen business timezone at the application boundary.

## Inventory and physical stock rules

`INVENTORY.ON_HAND_QTY` is physical saleable stock on hand. `RESERVED_QTY` includes both temporary checkout holds and paid allocations awaiting fulfilment. The invariant is `0 <= reserved_qty <= on_hand_qty`; available-to-promise is `on_hand_qty - reserved_qty`. The checks enforce the local row bounds but cannot by themselves prevent race conditions or guarantee agreement with open reservation rows.

Every stock movement is a physical change only. A receipt or return has a positive delta; a fulfilment has a strictly negative delta; an adjustment may be positive or negative. Each movement changes `ON_HAND_QTY` by the same delta in the same transaction. Reservation creation, payment, expiry, release, and cancellation do not create stock movements and do not alter `ON_HAND_QTY`. Treat the ledger as append-only; update/delete privilege controls are outside this schema draft.

Initial stock is represented by positive `RECEIPT` movements with a reason identifying the opening-stock source. The catalogue seed creates one inventory row and matching receipt movement per SKU, with equal opening quantities and no reservations. The transaction seed adds negative `FULFILMENT` movements for dispatched orders and reconciles physical and reserved stock.

## Order, reservation, payment, and fulfilment lifecycle

1. **Checkout begins:** create `ORDERS` as `PENDING` and its items. For each item, lock the `INVENTORY` row (for example, `SELECT ... FOR UPDATE`) and verify `on_hand_qty - reserved_qty >= requested quantity`. Insert one `CHECKOUT` reservation linked by composite foreign key to that exact order item, with expiry exactly ten minutes after reservation time; increment `reserved_qty` in the same transaction. The service must also verify reservation quantity equals its order-item quantity because a row-level constraint cannot compare those table values. Commit all item and reservation changes atomically or roll them all back.
2. **Payment attempt:** payment gateway integration is out of scope. The transaction seed records local simulated payment results; production payment handling requires a separately reviewed integration. A successful payment is accepted only while the checkout reservation remains unexpired and held. Mark payment `SUCCEEDED`, order `PAID`, and reservation `ALLOCATED`; keep `reserved_qty` unchanged. The ten-minute deadline applies only to checkout holds; paid allocations stay reserved until fulfilment or cancellation.
3. **Expiry or cancellation:** expiry applies only to unpaid `CHECKOUT` reservations. A future application worker/request path locks order, reservation, and inventory rows in a consistent order, changes the reservation to `EXPIRED`, sets the order to `EXPIRED` when no checkout remains, and decrements `reserved_qty` atomically. A cancellation before dispatch, including after payment, sets the order to `CANCELLED`, changes open reservations to `RELEASED`, and decrements `reserved_qty` atomically; any required payment refund is a separate payment state transition. Late payment after expiry needs a defined refund/manual-review path and must not consume unheld stock.
4. **Fulfilment:** only a paid, non-cancelled order can be dispatched. In one transaction, reduce both `on_hand_qty` and `reserved_qty` by fulfilled quantities, change reservations to `FULFILLED`, insert matching strictly negative `FULFILMENT` stock movements, stamp `fulfilled_at`, and set order `FULFILLED`. This atomically converts allocated physical stock into a completed physical stock movement. Reject fulfilment if either quantity would become negative.

The application must make reservation and inventory changes atomic, use row locks or equivalent serialization to prevent overselling, and keep a consistent lock order across checkout, payment result handling, expiry/cancellation, and fulfilment. The schema has no triggers, procedures, jobs, or enforcement of cross-row lifecycle transitions; those require separately reviewed application logic. `CHECK` constraints cover row-level invariants only.

## DBA review and approvals

- Approve the target schema owner, object naming, quotas/tablespace, and minimum grants for `FREEPDB1`; the DDL is intended to run as that owner, not SYS.
- Confirm the identity-column and `TIMESTAMP WITH TIME ZONE` choices against the exact 26ai Free patch level and operational conventions.
- Confirm email uniqueness/case normalization and SKU collation/normalization policy. Current unique constraints compare stored values according to the column collation and do not normalize input.
- Approve AUD-only fixed currency constraints, two-decimal prices, and the current no-tax/no-shipping total model.
- Approve order/payment/reservation state vocabularies, whether multiple payment attempts or partial fulfilment/refunds are needed, and the late-payment-after-expiry policy. `PAYMENT_REFERENCE` is nullable and unique when supplied.
- Approve retention and privacy requirements for customer contact data, audit timestamps, and immutable movement history.
- Decide how manual inventory corrections are authorized and whether adjustment reasons/references need stricter controlled vocabularies.
- Review transaction isolation, row-lock ordering, idempotency keys, retry behavior, and reconciliation needed to keep `RESERVED_QTY` equal to active reservation quantities. These are application/service requirements, not guaranteed by this DDL.

## Explicit exclusions

The core schema deployment includes no payment gateway integration, scheduled expiry job, trigger, stored procedure, recovery simulation, or Docker resource. Catalogue and transaction seeds are separate scripts. Lab 1 objects, scripts, volumes, and RMAN configuration were not changed.

## Seed troubleshooting note

An early catalogue seed used `INSERT ALL ... SELECT 1 FROM dual` for many rows in identity-backed tables. Oracle reused the generated identity value across the `INTO` clauses for that single source row, causing `ORA-00001` on `PRODUCTS_PK` even though `PRODUCTS` was empty after rollback. The corrected catalogue seed uses one `INSERT INTO ... VALUES` statement per product and customer. Resetting the identity sequence alone does not fix the multitable insert pattern. The transaction seed also uses one insert per identity-backed row.
