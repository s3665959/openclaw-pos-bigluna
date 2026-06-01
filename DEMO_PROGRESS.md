# Demo Progress

- Timestamp: 2026-06-01 17:23 ICT
- Flutter project path: `/home/april/projects/openclaw-pos-bigluna`
- OpenClaw web/backend inspected:
  - `/home/april/pos-dashboard`
  - `/home/april/dbd-search-package-20260523/backend/pos-dashboard-public.index.js`

## Completed

- Created a standalone Flutter demo app named `openclaw_pos_bigluna`
- Set app display name to `Big Luna POS`
- Added `.env.example` and local `.env` loading via `flutter_dotenv`
- Added optional `DEMO_READ_ONLY` safety gate for future safety mode
- Added Dio API client with optional bearer token support
- Added write-enabled demo helpers for stock adjustment, expiry, PO draft creation, PO confirmation, and goods receiving
- Built mobile-first Thai UI for:
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
- Added safe confirmation flow for stock adjustment, expiry lot create, PO creation, and goods receiving
- Added `DEMO_PROGRESS.md`

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
- `GET /pos-dashboard/api/sales/today`
- `GET /pos-dashboard/api/sales/summary/today`
- `GET /pos-dashboard/api/sales/top-products/today`
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

## Still limited / not exposed

- Historical sales date ranges are not exposed by the current connector
- Vendor create/edit flows are not wired
- Goods receiving is read-only in the demo UI
- Android SDK installed locally at `/home/april/projects/android-sdk`
- Android debug APK builds successfully in this environment
- Demo APK is built with `DEMO_READ_ONLY=false`

## Env setup

- Copy `.env.example` to `.env`
- Set `API_BASE_URL`
- Set `API_TOKEN` only if the backend requires it
- Set `DEMO_READ_ONLY=false` for full-function demo runs
- Set `DEMO_READ_ONLY=true` only when you want the safety mode

## Run

- `cd /home/april/projects/openclaw-pos-bigluna`
- `/home/april/projects/flutter-sdk/bin/flutter pub get`
- `/home/april/projects/flutter-sdk/bin/flutter test`
- `/home/april/projects/flutter-sdk/bin/flutter analyze`
- `/home/april/projects/flutter-sdk/bin/flutter build apk --debug`

## Validation results

- `flutter analyze`: passed
- `flutter test`: passed
- `flutter build apk --debug`: passed
- `flutter build web`: passed
- Debug APK output: `build/app/outputs/flutter-apk/app-debug.apk`

## Git

- Local git repo initialized in `/home/april/projects/openclaw-pos-bigluna`
- Initial commit created: `46de0fb` (`Initial Big Luna POS demo app`)
- Latest commit for this round: pending final commit after full-function changes
- Working tree has pending local changes for this round

## Next step

- If the live backend needs auth, populate `API_TOKEN` locally and re-test the app with `DEMO_READ_ONLY=false`
- Copy the debug APK to the demo device or install it with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
