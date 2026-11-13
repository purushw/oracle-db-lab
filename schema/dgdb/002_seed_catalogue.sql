-- Deterministic DGDB catalogue, fictional customers, and opening stock seed.
-- Run once as DGDB in FREEPDB1 after 001_core_schema.sql is deployed.
-- NOT SAFE TO RERUN: inserts are intentionally non-idempotent and will collide
-- with unique SKU/email constraints. Review the whole script before execution.
-- No identity values are supplied; foreign keys use SKU lookups instead.
-- Separate product/customer INSERT statements let each identity advance once
-- per row; INSERT ALL from one DUAL row repeats an identity value.

SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-001','Daily Grind Classic 8.0 Deck','7-ply maple street deck, 8.0 inch',109.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-002','Daily Grind Classic 8.25 Deck','7-ply maple street deck, 8.25 inch',109.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-003','Daily Grind Classic 8.5 Deck','7-ply maple street deck, 8.5 inch',109.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-004','Concrete Lines Deck 8.0','Maple deck with original geometric artwork',119.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-005','Concrete Lines Deck 8.25','Maple deck with original geometric artwork',119.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-006','Night Session Deck 8.0','7-ply maple deck with dark abstract graphic',114.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-007','Night Session Deck 8.25','7-ply maple deck with dark abstract graphic',114.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-DECK-008','Daily Grind Cruiser Deck 8.75','Directional maple cruiser deck',124.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-TRK-001','Forge Street Trucks 139','Pair of raw alloy street trucks, 139 mm',89.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-TRK-002','Forge Street Trucks 144','Pair of raw alloy street trucks, 144 mm',89.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-TRK-003','Forge Hollow Trucks 139','Pair of lightweight hollow axle trucks',119.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-TRK-004','Forge Hollow Trucks 144','Pair of lightweight hollow axle trucks',119.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-TRK-005','Forge Low Trucks 129','Pair of low-profile alloy trucks',84.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-TRK-006','Forge Mid Trucks 149','Pair of mid-height alloy trucks',89.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-WHL-001','Park Formula Wheels 52 mm','Set of four 99A street wheels',69.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-WHL-002','Park Formula Wheels 53 mm','Set of four 99A street wheels',69.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-WHL-003','Park Formula Wheels 54 mm','Set of four 99A street wheels',69.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-WHL-004','Smooth Roll Cruiser Wheels 56 mm','Set of four 78A cruiser wheels',79.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-WHL-005','Smooth Roll Cruiser Wheels 60 mm','Set of four 78A cruiser wheels',84.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-WHL-006','Park Formula Wheels 54 mm Wide','Set of four 101A wide street wheels',74.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-BRG-001','Daily Grind Bearings ABEC 5','Set of eight steel bearings with spacers',29.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-BRG-002','Daily Grind Bearings ABEC 7','Set of eight precision steel bearings',39.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-BRG-003','Daily Grind Bearings Ceramic','Set of eight ceramic hybrid bearings',89.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-BRG-004','Daily Grind Bearings Service Pack','Eight bearings with cleaning lubricant',34.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-CMP-001','Daily Grind Complete 8.0','Complete street setup with 139 mm trucks',259.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-CMP-002','Daily Grind Complete 8.25','Complete street setup with 144 mm trucks',259.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-CMP-003','Daily Grind Complete 7.75','Complete youth street setup',249.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-CMP-004','Daily Grind Cruiser Complete','Cruiser setup with soft 60 mm wheels',289.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-CMP-005','Daily Grind Complete 8.5','Wide street setup with 149 mm trucks',269.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-CMP-006','Daily Grind Mini Complete','Compact complete setup for smaller riders',239.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-001','Daily Grind Black Griptape','Single sheet, 9 by 33 inch',14.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-002','Daily Grind Clear Griptape','Single clear sheet, 9 by 33 inch',19.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-003','Hardware Set 7/8 Inch','Eight bolts and nuts for standard setup',9.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-004','Hardware Set 1 Inch','Eight bolts and nuts for riser setup',9.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-005','Riser Pads 1/8 Inch','Pair of shock-absorbing riser pads',12.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-006','Skate Tool Multi-Key','Pocket tool for common truck hardware',24.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-007','Daily Grind Wax Brick','Compact skate wax for ledges and curbs',8.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-008','Daily Grind Canvas Tote','Reusable skate shop carry tote',24.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-009','Daily Grind Logo Socks','Cotton blend crew socks, one size',18.95);
INSERT INTO products (sku, product_name, description, unit_price) VALUES ('DG-ACC-010','Daily Grind Water Bottle','Reusable 700 ml bottle',22.95);

INSERT INTO customers (email, given_name, family_name) VALUES ('riley01@example.test','Riley','Carter');
INSERT INTO customers (email, given_name, family_name) VALUES ('jordan02@example.test','Jordan','Nguyen');
INSERT INTO customers (email, given_name, family_name) VALUES ('casey03@example.test','Casey','Morgan');
INSERT INTO customers (email, given_name, family_name) VALUES ('taylor04@example.test','Taylor','Brooks');
INSERT INTO customers (email, given_name, family_name) VALUES ('alex05@example.test','Alex','Patel');
INSERT INTO customers (email, given_name, family_name) VALUES ('sam06@example.test','Sam','Reed');
INSERT INTO customers (email, given_name, family_name) VALUES ('morgan07@example.test','Morgan','Ellis');
INSERT INTO customers (email, given_name, family_name) VALUES ('jamie08@example.test','Jamie','Price');
INSERT INTO customers (email, given_name, family_name) VALUES ('avery09@example.test','Avery','Kim');
INSERT INTO customers (email, given_name, family_name) VALUES ('quinn10@example.test','Quinn','Foster');
INSERT INTO customers (email, given_name, family_name) VALUES ('drew11@example.test','Drew','Bell');
INSERT INTO customers (email, given_name, family_name) VALUES ('reese12@example.test','Reese','Ward');
INSERT INTO customers (email, given_name, family_name) VALUES ('skyler13@example.test','Skyler','Cruz');
INSERT INTO customers (email, given_name, family_name) VALUES ('rowan14@example.test','Rowan','Murphy');
INSERT INTO customers (email, given_name, family_name) VALUES ('finley15@example.test','Finley','Ross');
INSERT INTO customers (email, given_name, family_name) VALUES ('devon16@example.test','Devon','Cooper');
INSERT INTO customers (email, given_name, family_name) VALUES ('harper17@example.test','Harper','Bailey');
INSERT INTO customers (email, given_name, family_name) VALUES ('logan18@example.test','Logan','Rivera');
INSERT INTO customers (email, given_name, family_name) VALUES ('peyton19@example.test','Peyton','Gray');
INSERT INTO customers (email, given_name, family_name) VALUES ('dakota20@example.test','Dakota','Flores');
INSERT INTO customers (email, given_name, family_name) VALUES ('emery21@example.test','Emery','Hughes');
INSERT INTO customers (email, given_name, family_name) VALUES ('kai22@example.test','Kai','Bennett');
INSERT INTO customers (email, given_name, family_name) VALUES ('remy23@example.test','Remy','Wood');
INSERT INTO customers (email, given_name, family_name) VALUES ('sasha24@example.test','Sasha','Perry');
INSERT INTO customers (email, given_name, family_name) VALUES ('noel25@example.test','Noel','Long');
INSERT INTO customers (email, given_name, family_name) VALUES ('blake26@example.test','Blake','Powell');
INSERT INTO customers (email, given_name, family_name) VALUES ('ellis27@example.test','Ellis','Jenkins');
INSERT INTO customers (email, given_name, family_name) VALUES ('marley28@example.test','Marley','Parker');
INSERT INTO customers (email, given_name, family_name) VALUES ('river29@example.test','River','Collins');
INSERT INTO customers (email, given_name, family_name) VALUES ('frankie30@example.test','Frankie','Stewart');
INSERT INTO customers (email, given_name, family_name) VALUES ('indigo31@example.test','Indigo','Morris');
INSERT INTO customers (email, given_name, family_name) VALUES ('micah32@example.test','Micah','Rogers');
INSERT INTO customers (email, given_name, family_name) VALUES ('ellis33@example.test','Ellis','Cook');
INSERT INTO customers (email, given_name, family_name) VALUES ('arden34@example.test','Arden','Bailey');
INSERT INTO customers (email, given_name, family_name) VALUES ('jules35@example.test','Jules','Kelly');
INSERT INTO customers (email, given_name, family_name) VALUES ('kit36@example.test','Kit','Sanders');
INSERT INTO customers (email, given_name, family_name) VALUES ('lennox37@example.test','Lennox','Turner');
INSERT INTO customers (email, given_name, family_name) VALUES ('phoenix38@example.test','Phoenix','Parker');
INSERT INTO customers (email, given_name, family_name) VALUES ('ellis39@example.test','Ellis','Ward');
INSERT INTO customers (email, given_name, family_name) VALUES ('river40@example.test','River','Price');
INSERT INTO customers (email, given_name, family_name) VALUES ('charlie41@example.test','Charlie','Hayes');
INSERT INTO customers (email, given_name, family_name) VALUES ('max42@example.test','Max','Bishop');
INSERT INTO customers (email, given_name, family_name) VALUES ('billie43@example.test','Billie','Russell');
INSERT INTO customers (email, given_name, family_name) VALUES ('ash44@example.test','Ash','Griffin');
INSERT INTO customers (email, given_name, family_name) VALUES ('cameron45@example.test','Cameron','Diaz');
INSERT INTO customers (email, given_name, family_name) VALUES ('shiloh46@example.test','Shiloh','Henderson');
INSERT INTO customers (email, given_name, family_name) VALUES ('milan47@example.test','Milan','Coleman');
INSERT INTO customers (email, given_name, family_name) VALUES ('winter48@example.test','Winter','Simmons');
INSERT INTO customers (email, given_name, family_name) VALUES ('sonny49@example.test','Sonny','Fisher');
INSERT INTO customers (email, given_name, family_name) VALUES ('aria50@example.test','Aria','Armstrong');

-- Opening stock is deliberately balanced: one inventory row and one receipt
-- movement per SKU, each with the same positive quantity. All inventory starts
-- unreserved. The SKU join resolves identity-generated product IDs without
-- assuming a sequence value or hard-coding an identity ID.
INSERT INTO inventory (product_id, on_hand_qty, reserved_qty, reorder_level)
SELECT p.product_id, s.opening_qty, 0, s.reorder_level
FROM products p
JOIN (
    SELECT 'DG-DECK-001' sku, 18 opening_qty, 4 reorder_level FROM dual UNION ALL
    SELECT 'DG-DECK-002', 16, 4 FROM dual UNION ALL
    SELECT 'DG-DECK-003', 12, 3 FROM dual UNION ALL
    SELECT 'DG-DECK-004', 10, 3 FROM dual UNION ALL
    SELECT 'DG-DECK-005', 10, 3 FROM dual UNION ALL
    SELECT 'DG-DECK-006', 8, 2 FROM dual UNION ALL
    SELECT 'DG-DECK-007', 8, 2 FROM dual UNION ALL
    SELECT 'DG-DECK-008', 7, 2 FROM dual UNION ALL
    SELECT 'DG-TRK-001', 22, 5 FROM dual UNION ALL
    SELECT 'DG-TRK-002', 20, 5 FROM dual UNION ALL
    SELECT 'DG-TRK-003', 12, 3 FROM dual UNION ALL
    SELECT 'DG-TRK-004', 12, 3 FROM dual UNION ALL
    SELECT 'DG-TRK-005', 9, 2 FROM dual UNION ALL
    SELECT 'DG-TRK-006', 10, 3 FROM dual UNION ALL
    SELECT 'DG-WHL-001', 24, 6 FROM dual UNION ALL
    SELECT 'DG-WHL-002', 24, 6 FROM dual UNION ALL
    SELECT 'DG-WHL-003', 20, 5 FROM dual UNION ALL
    SELECT 'DG-WHL-004', 14, 4 FROM dual UNION ALL
    SELECT 'DG-WHL-005', 12, 3 FROM dual UNION ALL
    SELECT 'DG-WHL-006', 12, 3 FROM dual UNION ALL
    SELECT 'DG-BRG-001', 30, 8 FROM dual UNION ALL
    SELECT 'DG-BRG-002', 28, 7 FROM dual UNION ALL
    SELECT 'DG-BRG-003', 10, 3 FROM dual UNION ALL
    SELECT 'DG-BRG-004', 16, 4 FROM dual UNION ALL
    SELECT 'DG-CMP-001', 8, 2 FROM dual UNION ALL
    SELECT 'DG-CMP-002', 8, 2 FROM dual UNION ALL
    SELECT 'DG-CMP-003', 6, 2 FROM dual UNION ALL
    SELECT 'DG-CMP-004', 5, 1 FROM dual UNION ALL
    SELECT 'DG-CMP-005', 5, 1 FROM dual UNION ALL
    SELECT 'DG-CMP-006', 5, 1 FROM dual UNION ALL
    SELECT 'DG-ACC-001', 40, 10 FROM dual UNION ALL
    SELECT 'DG-ACC-002', 18, 4 FROM dual UNION ALL
    SELECT 'DG-ACC-003', 35, 8 FROM dual UNION ALL
    SELECT 'DG-ACC-004', 28, 7 FROM dual UNION ALL
    SELECT 'DG-ACC-005', 20, 5 FROM dual UNION ALL
    SELECT 'DG-ACC-006', 16, 4 FROM dual UNION ALL
    SELECT 'DG-ACC-007', 32, 8 FROM dual UNION ALL
    SELECT 'DG-ACC-008', 12, 3 FROM dual UNION ALL
    SELECT 'DG-ACC-009', 18, 4 FROM dual UNION ALL
    SELECT 'DG-ACC-010', 14, 3 FROM dual
) s ON s.sku = p.sku;

INSERT INTO stock_movements (
    product_id, movement_type, quantity_delta, reason, reference_type, reference_id
)
SELECT p.product_id, 'RECEIPT', s.opening_qty,
       'Opening catalogue stock seed', NULL, NULL
FROM products p
JOIN (
    SELECT 'DG-DECK-001' sku, 18 opening_qty FROM dual UNION ALL
    SELECT 'DG-DECK-002', 16 FROM dual UNION ALL
    SELECT 'DG-DECK-003', 12 FROM dual UNION ALL
    SELECT 'DG-DECK-004', 10 FROM dual UNION ALL
    SELECT 'DG-DECK-005', 10 FROM dual UNION ALL
    SELECT 'DG-DECK-006', 8 FROM dual UNION ALL
    SELECT 'DG-DECK-007', 8 FROM dual UNION ALL
    SELECT 'DG-DECK-008', 7 FROM dual UNION ALL
    SELECT 'DG-TRK-001', 22 FROM dual UNION ALL
    SELECT 'DG-TRK-002', 20 FROM dual UNION ALL
    SELECT 'DG-TRK-003', 12 FROM dual UNION ALL
    SELECT 'DG-TRK-004', 12 FROM dual UNION ALL
    SELECT 'DG-TRK-005', 9 FROM dual UNION ALL
    SELECT 'DG-TRK-006', 10 FROM dual UNION ALL
    SELECT 'DG-WHL-001', 24 FROM dual UNION ALL
    SELECT 'DG-WHL-002', 24 FROM dual UNION ALL
    SELECT 'DG-WHL-003', 20 FROM dual UNION ALL
    SELECT 'DG-WHL-004', 14 FROM dual UNION ALL
    SELECT 'DG-WHL-005', 12 FROM dual UNION ALL
    SELECT 'DG-WHL-006', 12 FROM dual UNION ALL
    SELECT 'DG-BRG-001', 30 FROM dual UNION ALL
    SELECT 'DG-BRG-002', 28 FROM dual UNION ALL
    SELECT 'DG-BRG-003', 10 FROM dual UNION ALL
    SELECT 'DG-BRG-004', 16 FROM dual UNION ALL
    SELECT 'DG-CMP-001', 8 FROM dual UNION ALL
    SELECT 'DG-CMP-002', 8 FROM dual UNION ALL
    SELECT 'DG-CMP-003', 6 FROM dual UNION ALL
    SELECT 'DG-CMP-004', 5 FROM dual UNION ALL
    SELECT 'DG-CMP-005', 5 FROM dual UNION ALL
    SELECT 'DG-CMP-006', 5 FROM dual UNION ALL
    SELECT 'DG-ACC-001', 40 FROM dual UNION ALL
    SELECT 'DG-ACC-002', 18 FROM dual UNION ALL
    SELECT 'DG-ACC-003', 35 FROM dual UNION ALL
    SELECT 'DG-ACC-004', 28 FROM dual UNION ALL
    SELECT 'DG-ACC-005', 20 FROM dual UNION ALL
    SELECT 'DG-ACC-006', 16 FROM dual UNION ALL
    SELECT 'DG-ACC-007', 32 FROM dual UNION ALL
    SELECT 'DG-ACC-008', 12 FROM dual UNION ALL
    SELECT 'DG-ACC-009', 18 FROM dual UNION ALL
    SELECT 'DG-ACC-010', 14 FROM dual
) s ON s.sku = p.sku;

COMMIT;
