# Demo Progress

- Timestamp: 2026-06-02 04:00 +07
- Flutter project path: `/home/april/projects/openclaw-pos-bigluna`
- OpenClaw reference paths inspected:
  - `/home/april/pos-dashboard`
  - `/home/april/projects/openclaw-pos-platform`

## What was fixed

- Root cause for the Android APK mismatch: the Flutter client was calling the host root instead of the connector prefix, so requests such as `/products/list`, `/products/search`, `/stock/summary`, `/products/count`, `/sales/today`, and `/barcode/lookup` were going to the wrong URL and returning HTML, empty data, or misleading fallback values.
- `AppConfig` now normalizes `API_BASE_URL=https://openclaw.ganseeds.com` to the live connector prefix `/pos-dashboard/api`, matching the web app.
- Dashboard and System Status were showing misleading values because some model parsing and UI fallbacks were turning missing or failed API data into `0`, `-`, or `unknown`.
- `ConnectorHealth.mode` now falls back to `write-enabled` or `read-only` instead of `unknown`.
- `DatabaseInfo` no longer invents a database name when the API does not provide one.
- Sales screen no longer defaults summary totals to zero on request failure.
- Missing API data is now displayed as `Not provided by API` or `API error` instead of fake values.
- Mobile layouts were tightened to remove overflow on Dashboard, System Status, Inventory, Vendors, and Sales by increasing card height and improving text wrapping.
- Scan screen layout was fixed so the barcode scanner card no longer has malformed nesting.
- The app language now defaults to English and can be switched between English and Vietnamese from Settings.
- The demo mode banner now reflects write-enabled mode in English and Vietnamese.
- Scan Barcode and Products now share the same action sheet for:
  - adjust stock
  - edit product
  - manage suppliers
  - add expiry lot
- Sales now supports a selected business date by reading archive runs from the backend and loading the matching sales detail when the date is not today.
- Product edit refresh now prefers fresh `barcode/lookup` data and only falls back to `products/detail` for missing fields, because `products/detail` can lag behind a write.
- Scan Barcode now plays a confirmation sound/vibration on successful scan and auto-scrolls to the product actions block.
- Product cost updates now keep raw POS `CostPrice` separate from OpenClaw `effective_cost` / supplier `last_cost`, while keeping `DefaultVendor` out of the save blocker path.
- The corrected POS connector now exposes raw product cost as `dbo.StockItems.LastOrderPrice`, so Edit Product prefills from `pos_expected_cost` and preserves `openclaw_supplier_last_cost` as a separate supplier reference.
- The runtime product detail/update flow now returns raw POS cost and supplier cost independently, so the UI no longer falls back to `0` when `pos_expected_cost` is present.
- False `pos_expected_cost_update_failed` warnings are now suppressed in the mobile client when the returned `pos_expected_cost` already matches the submitted cost.

## Completed

- Created the standalone Flutter demo app `openclaw_pos_bigluna`
- Kept full-function demo mode enabled with `DEMO_READ_ONLY=false`
- Added `.env.example` and local `.env` loading via `flutter_dotenv`
- Added Dio API client with optional bearer token support
- Added write-enabled demo helpers for:
  - stock adjustment
  - product edit
  - supplier management
  - expiry lot maintenance
  - expiry lot creation
  - purchase order draft creation
  - purchase order confirmation
  - goods receiving
- Added language persistence with `shared_preferences`
- Added a simple localization layer for English and Vietnamese
- Added a Settings screen for locale selection
- Built mobile-first UI for:
  - Dashboard
  - Products
  - Barcode Scan
  - Inventory
  - Sales
  - Vendors
  - Purchase Orders
  - Goods Receiving
  - Stock Adjustment
  - Expiry Lots
  - System Status

## Live API endpoints connected

- `GET /pos-dashboard/api/health`
- `GET /pos-dashboard/api/db/test`
- `GET /pos-dashboard/api/products/list`
- `GET /pos-dashboard/api/products/search`
- `GET /pos-dashboard/api/products/detail`
- `GET /pos-dashboard/api/barcode/lookup`
- `GET /pos-dashboard/api/products/count`
- `GET /pos-dashboard/api/stock/summary`
- `GET /pos-dashboard/api/stock/low`
- `GET /pos-dashboard/api/stock/out`
- `GET /pos-dashboard/api/stock/negative`
- `GET /pos-dashboard/api/stock/recent-adjustments`
- `POST /pos-dashboard/api/stock/direct-adjust`
- `POST /pos-dashboard/api/products/update`
- `GET /pos-dashboard/api/product-suppliers?stock_id=`
- `POST /pos-dashboard/api/product-suppliers`
- `PUT /pos-dashboard/api/product-suppliers/:id`
- `DELETE /pos-dashboard/api/product-suppliers/:id`
- `GET /pos-dashboard/api/expiry/next-batch-no?stock_id=`
- `PUT /pos-dashboard/api/expiry/:id`
- `DELETE /pos-dashboard/api/expiry/:id`
- `GET /pos-dashboard/api/sales/today`
- `GET /pos-dashboard/api/sales/summary/today`
- `GET /pos-dashboard/api/sales/top-products/today`
- `GET /pos-dashboard/api/archive/runs?month=YYYY-MM&page=1&page_size=50`
- `GET /pos-dashboard/api/archive/runs/:id/sales-detail?page=1&limit=200&sort=transaction_desc`
- `GET /pos-dashboard/api/vendors/search`
- `GET /pos-dashboard/api/vendors/summary`
- `GET /pos-dashboard/api/vendors/:id`
- `GET /pos-dashboard/api/vendors/:id/products`
- `GET /pos-dashboard/api/purchase-orders`
- `GET /pos-dashboard/api/purchase-orders/:id`
- `GET /pos-dashboard/api/purchase-orders/:id/receiving-status`
- `GET /pos-dashboard/api/goods-receiving`
- `GET /pos-dashboard/api/goods-receiving/:id`
- `POST /pos-dashboard/api/purchase-order-drafts`
- `POST /pos-dashboard/api/purchase-order-drafts/:id/items`
- `POST /pos-dashboard/api/purchase-order-drafts/:id/group-by-supplier`
- `POST /pos-dashboard/api/purchase-order-drafts/:id/create-purchase-orders`
- `POST /pos-dashboard/api/goods-receiving`
- `GET /pos-dashboard/api/expiry/summary`
- `GET /pos-dashboard/api/expiry?stock_id=`
- `POST /pos-dashboard/api/expiry`
- `GET /pos-dashboard/api/product-suppliers?stock_id=`

## Live write verification

- Stock adjustment product: `00001111` (`BO WAGU`)
- Before stock: `10`
- Increase: `+1` via `POST /stock/direct-adjust`
- After increase: `11`
- Decrease: `-2` via `POST /stock/direct-adjust`
- After decrease: `9`
- Product edit verification:
  - `POST /pos-dashboard/api/products/update`
  - Product: `00001111`
  - Before: name `BO WAGU`, cost `0`, selling `49.99`
  - After: name `BO WAGU`, cost `0`, selling `50.49`
  - Backend response reported `changed_fields=["cost_price","selling_price"]`
- ABALONE SAUCE cost verification:
  - `014268800937` default supplier is `GOLD STAR / 00021`
  - Cost updates now refresh OpenClaw supplier `last_cost` and return `pos_expected_cost` from raw POS `LastOrderPrice`
  - `DefaultVendor` remains `NULL` and does not block save
- Sales date verification:
  - `2026-05-30` uses archive run `287ffb71-ffe7-477f-8d87-efc49eb6ef8f`
  - `amount_total=1842.0700000000002`
  - `invoice_count=185`
  - `2026-05-31` has no verified sales rows, so Flutter now shows `No sales data` instead of fake `0`
- Expiry lot create:
  - `stock_id`: `00001111`
  - `batch_no`: `BL-DEMO-0001`
  - `expiry_date`: `2026-07-31`
  - `qty`: `1`
- PO/GR write verification:
  - Product: `0000888` (`FROZEN SQUID EGGS MUC TRUNG`)
  - Supplier mapping found: `GOLD STAR`
  - Created draft `POD-20260601-0006`
  - Created PO `PO-20260601-0001`
  - Saved goods receipt `GR-20260601-0001`

## Environment

- `API_BASE_URL=https://openclaw.ganseeds.com`
- `API_TOKEN=` only if the backend requires it
- `DEMO_READ_ONLY=false` for full-function demo builds

## Validation

- `flutter pub get`: passed
- `flutter analyze`: passed
- `flutter test`: passed
- `flutter build apk --debug`: passed
- Debug APK output: `build/app/outputs/flutter-apk/app-debug.apk`
- Verified live connector endpoints from the corrected prefix:
  - `GET /pos-dashboard/api/products/list?q=orange`
  - `GET /pos-dashboard/api/products/search?q=orange`
  - `GET /pos-dashboard/api/barcode/lookup?code=orange`
  - `GET /pos-dashboard/api/stock/summary`
  - `GET /pos-dashboard/api/products/count`
  - `GET /pos-dashboard/api/archive/runs?month=2026-05&page=1&page_size=50`
  - `GET /pos-dashboard/api/archive/runs/287ffb71-ffe7-477f-8d87-efc49eb6ef8f/sales-detail?page=1&limit=2&sort=transaction_desc`
- `POST /pos-dashboard/api/products/update` for `00001111`

## Notes

- Root cause for `default_vendor_cost_not_found`:
  - The failing product `ABALONE SAUCE` (`014268800937`) has a default supplier relation in `/product-suppliers`, but the product master still reports `DefaultVendor = NULL`.
  - Live comparison shows products that save successfully already have a non-null `DefaultVendor` value in the product master, so the public supplier mapping API is not enough to initialize the backend cost row.
  - The live public API did not expose a supported write endpoint to set the missing product-master default vendor linkage directly.
- Flutter changes in this round:
  - Product actions now report the backend blocker more clearly when the default vendor cost row is missing.
  - Expiry lot date inputs now open a date picker in both the shared product actions sheet and the operations screen.
  - Product cost now prefers POS `pos_expected_cost` (`dbo.StockItems.LastOrderPrice`) and keeps the confirmed update response value if the immediate detail refresh is briefly stale.
  - Product update warnings suppress `pos_expected_cost_update_failed` when the server confirms the submitted cost.
  - Products and Inventory list cards now show `Cost / Retail Price` instead of the old vendor/`Unknown` compact subtitle.
  - Home screen is now simplified to four primary cards only: Scan Barcode, Products, Sales, and System Status.
  - Launcher icons were updated from the provided `/home/april/projects/icon` asset set.
- Android SDK is installed at `/home/april/projects/android-sdk`
- `JAVA_HOME` must point to `/home/april/projects/java-17` for Android builds in this shell
- No Android device was attached when checking `adb devices`, so I could not capture a fresh on-device screenshot from this environment
- No backup, snapshot, reset, or rollback was performed
- No changes were made to `/home/april/pos-dashboard` or `/home/april/projects/openclaw-pos-platform`
- Added daily gross profit reporting to Sales using the shared OpenClaw endpoint `GET /pos-dashboard/api/sales/profit-report?date=YYYY-MM-DD`
- Cost basis for the new report:
  - No historical cost per sale line is exposed by the live POS sales endpoints or archive item rows
  - Gross profit therefore uses current POS product cost (`pos_expected_cost` / `dbo.StockItems.LastOrderPrice`) with OpenClaw supplier last-cost fallback when the POS cost is unavailable
- Verified report output on live/public API:
  - `2026-06-02`: Total Sales `2884.15`, COGS `390.87`, Gross Profit `2493.28`, Gross Margin `86.45%`, Orders `208`
  - `2026-06-01`: Total Sales `1904.24`, COGS `483.20`, Gross Profit `1421.04`, Gross Margin `74.63%`, Orders `158`
- Flutter Sales screen now:
  - Loads a selected-date gross profit report from the shared backend
  - Shows summary cards for Total Sales, Gross Profit, Gross Margin, Orders, Items Sold, COGS, and Average Order Value
  - Shows Top Products by Profit, Top Products by Quantity Sold, and Low / Negative Profit Items
  - Uses Australian dollar formatting (`A$`)
  - Keeps the Today shortcut, date picker, loading state, empty state, retry, and API error handling

## Git

- Local git repo is initialized in `/home/april/projects/openclaw-pos-bigluna`
- Latest commit hash: pending final commit after this fix set
