# Smart Delivery System - Frontend API Contract

This document maps the frontend screens to the current backend API endpoints.

The goal is to help the frontend team build the Web Admin Dashboard, Flutter Customer App, Flutter Courier App, and Locker Device screen without guessing backend behavior.

## 1. System Surfaces

| Surface | Users | Purpose |
| --- | --- | --- |
| Web Admin Dashboard | admin, operations, support | Manage orders, lockers, drawers, devices, couriers, notifications, and audit logs. |
| Flutter Mobile App | customer, courier | Routes customers to shopping and couriers to their assigned delivery and return work based on the authenticated account role. |
| Locker Device Screen | locker_device | Send heartbeat, scan QR tokens, open drawers, and confirm collection or return actions. |

## 2. Base URLs

Local Docker development:

```text
http://127.0.0.1:8000
```

API base:

```text
http://127.0.0.1:8000/api
```

Health endpoints:

```http
GET /health/
GET /ready/
```

OpenAPI documentation, when enabled:

```http
GET /api/schema/
GET /api/docs/
```

## 3. Authentication

Most endpoints require JWT authentication.

### 3.1 Login

```http
POST /api/token/
```

Request body:

```json
{
  "username": "demo-admin",
  "password": "demo-password"
}
```

Response shape:

```json
{
  "access": "...",
  "refresh": "...",
  "user": {
    "id": 1,
    "username": "demo-admin",
    "first_name": "",
    "last_name": "",
    "email": "",
    "phone": "",
    "role": "admin"
  }
}
```

All authenticated requests must include:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

### 3.2 Refresh Token

```http
POST /api/token/refresh/
```

Request body:

```json
{
  "refresh": "<refresh_token>"
}
```

### 3.3 Logout

```http
POST /api/accounts/logout/
Authorization: Bearer <access_token>
```

Request body:

```json
{
  "refresh": "<refresh_token>"
}
```

## 4. Roles

Use the role returned by `/api/accounts/me/` or the login response to choose the correct UI.

| Role | UI |
| --- | --- |
| customer | Flutter Customer App |
| courier | Flutter Courier App |
| admin | Web Admin Dashboard |
| locker_device | Locker Device Screen or hardware integration |

## 5. Important Headers

Normal authenticated requests:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

Locker device mutation requests must also include:

```http
Idempotency-Key: <uuid>
```

The `Idempotency-Key` is required when the locker device sends a physical action request, such as opening a drawer or confirming collection. Generate a new UUID for each new operation. Reuse the same UUID only when retrying the exact same request after a timeout or network failure.

## 6. Account APIs

### 6.1 Register Customer

Used by the Customer App registration screen.

```http
POST /api/accounts/register/
```

Request body:

```json
{
  "username": "customer1",
  "password": "StrongPassword123",
  "password_confirm": "StrongPassword123",
  "first_name": "Kareem",
  "last_name": "Ali",
  "email": "customer@example.com",
  "phone": "+201000000000"
}
```

Expected result:

- Creates a customer account.
- Returns user profile plus JWT tokens.

### 6.2 My Account

Used by all frontends after login.

```http
GET /api/accounts/me/
Authorization: Bearer <access_token>
```

Response shape:

```json
{
  "id": 2,
  "username": "demo-customer",
  "first_name": "",
  "last_name": "",
  "email": "",
  "phone": "",
  "role": "customer"
}
```

Update profile:

```http
PATCH /api/accounts/me/
Authorization: Bearer <access_token>
```

Request body example:

```json
{
  "first_name": "Kareem",
  "last_name": "Ali",
  "email": "customer@example.com",
  "phone": "+201000000000"
}
```

### 6.3 Change Password

```http
POST /api/accounts/change-password/
Authorization: Bearer <access_token>
```

Request body:

```json
{
  "current_password": "old-password",
  "new_password": "new-password",
  "new_password_confirm": "new-password"
}
```

## 7. Customer Mobile App APIs

The Customer App behaves like a small e-commerce app connected to smart locker pickup.

### 7.1 Products List

Screen: Customer products or home screen.

```http
GET /api/products/
```

Main fields:

```json
{
  "id": 1,
  "name": "Demo Phone Case",
  "category": 1,
  "category_name": "Accessories",
  "image": "http://127.0.0.1:8000/media/products/phone-case.png",
  "description": "...",
  "price": "250.00",
  "stock": 10,
  "size": "small",
  "is_active": true,
  "created_at": "...",
  "updated_at": "..."
}
```

Notes:

- Customers should display active products.
- Admin/support screens can use product state to manage availability.
- Products without a category return `category: null` and `category_name: null` until assigned.
- Product writes accept `multipart/form-data` with an optional `image` file (JPEG, PNG, or WebP, up to 5 MB). The API returns the absolute image URL or `null`.

### 7.1.1 Product Categories

List active categories for customer-facing product browsing:

```http
GET /api/products/categories/
```

Admin category management:

```http
GET  /api/products/admin/categories/
POST /api/products/admin/categories/
PATCH /api/products/admin/categories/{id}/
Authorization: Bearer <admin_access_token>
```

Category fields are `id`, `name`, `description`, and `is_active`. Deactivate a
category instead of deleting it so existing product relationships remain intact.
Admins assign a category to a product with `category_id` when creating or
updating it; send `null` to remove the assignment.

### 7.2 Product Detail

Screen: Product details.

```http
GET /api/products/{id}/
```

### 7.3 Create Order

Screen: Checkout or create order.

```http
POST /api/orders/
Authorization: Bearer <customer_access_token>
```

Request body:

```json
{
  "locker_station_id": 1,
  "items": [
    {
      "product_id": 1,
      "quantity": 1
    }
  ]
}
```

Response main fields:

```json
{
  "public_id": "uuid",
  "status": "assigned",
  "total_amount": "250.00",
  "locker": {
    "id": 1,
    "name": "Demo Locker Maadi",
    "code": "DEMO-MAADI-001",
    "address": "Maadi, Cairo"
  },
  "items": [
    {
      "product": 1,
      "product_name": "Demo Phone Case",
      "product_size": "small",
      "unit_price": "250.00",
      "quantity": 1,
      "line_total": "250.00"
    }
  ]
}
```

Before submitting, the customer app requests eligible pickup stations for the
products in the cart. The backend filters online stations with an available
drawer large enough for the largest item and sorts them by distance when a
location is supplied:

```http
GET /api/lockers/nearby/?product_ids=1,2&latitude=29.960235&longitude=31.256537
Authorization: Bearer <customer_access_token>
```

Location coordinates are optional; without them, eligible stations are listed
without a distance sort. The order endpoint revalidates capacity and reserves a
compatible drawer atomically. If capacity changed after the list was loaded,
the order is rejected and the customer must choose another station.

### 7.4 Customer Orders List

Screen: My Orders.

```http
GET /api/orders/
Authorization: Bearer <customer_access_token>
```

Expected behavior:

- Customer sees own orders.
- Admin uses the admin order endpoint for operational views.

### 7.5 Order Detail

Screen: Order detail or tracking.

```http
GET /api/orders/{public_id}/
Authorization: Bearer <access_token>
```

Important fields:

- `public_id`
- `status`
- `total_amount`
- `locker`
- `courier_assigned_at`
- `assigned_at`
- `ready_for_pickup_at`
- `delivery_deadline`
- `collected_at`
- `returned_at`
- `cancelled_at`
- `items`

### 7.6 Order Tracking

Screen: Customer order tracking. Customers can only track their own orders.

```http
GET /api/orders/{public_id}/tracking/
Authorization: Bearer <customer_access_token>
```

The response includes the current order status, assigned courier when present,
the selected locker and reserved drawer, and timeline timestamps. It does not
provide live courier GPS; the timeline reflects persisted order events.

```json
{
  "order_id": "uuid",
  "tracking_number": "uuid",
  "status": "assigned",
  "courier": "courier username",
  "estimated_delivery": null,
  "locker_name": "Maadi Test Locker",
  "locker_address": "Maadi, Cairo",
  "locker_code": "TEST-MAADI-02",
  "drawer_number": 1,
  "steps": [
    {
      "title": "Order placed",
      "description": "Your order was created.",
      "timestamp": "...",
      "isCompleted": true,
      "isCurrent": false
    }
  ]
}
```

### 7.7 Cancel Order

Screen action: Cancel order button.

```http
POST /api/orders/{public_id}/cancel/
Authorization: Bearer <customer_access_token>
```

### 7.8 Pickup QR

Screen: Pickup QR.

```http
POST /api/orders/{public_id}/pickup-qr/
Authorization: Bearer <customer_access_token>
```

Response shape:

```json
{
  "token": "raw-pickup-token",
  "expires_at": "...",
  "order_public_id": "uuid",
  "locker_name": "Demo Locker Maadi",
  "locker_code": "DEMO-MAADI-001",
  "locker_address": "Maadi, Cairo, Egypt"
}
```

Frontend notes:

- Render `token` as a QR code.
- Treat token as sensitive data.
- Do not log QR tokens.

### 7.9 Customer Notifications

Screen: Notifications list.

```http
GET /api/notifications/
Authorization: Bearer <customer_access_token>
```

Unread filter:

```http
GET /api/notifications/?unread=true
```

Response item:

```json
{
  "id": 1,
  "notification_type": "order_ready_for_pickup",
  "title": "Order ready for pickup",
  "message": "Your order is ready for pickup.",
  "data": {},
  "order_public_id": "uuid",
  "is_read": false,
  "delivery_status": "sent",
  "delivery_attempts": 1,
  "delivered_at": "...",
  "delivery_error": "",
  "read_at": null,
  "created_at": "..."
}
```

Mark one notification as read:

```http
POST /api/notifications/{id}/read/
Authorization: Bearer <access_token>
```

Mark all notifications as read:

```http
POST /api/notifications/read-all/
Authorization: Bearer <access_token>
```

## 8. Courier Mobile App APIs

### 8.1 Assigned Orders

Screen: Courier assigned orders.

```http
GET /api/orders/courier/assignments/
Authorization: Bearer <courier_access_token>
```

Response item fields:

```json
{
  "public_id": "uuid",
  "status": "assigned",
  "locker_name": "Demo Locker Maadi",
  "locker_code": "DEMO-MAADI-001",
  "locker_address": "Maadi, Cairo, Egypt",
  "locker_latitude": "30.062630",
  "locker_longitude": "31.335220",
  "drawer_number": 1,
  "courier_assigned_at": "...",
  "assigned_at": "...",
  "created_at": "...",
  "items": [
    {
      "product_name": "Demo Phone Case",
      "product_size": "small",
      "quantity": 1
    }
  ]
}
```

### 8.2 Return Orders

Screen: Courier expired return tasks.

```http
GET /api/orders/courier/returns/
Authorization: Bearer <courier_access_token>
```

### 8.3 Return QR

Screen: Courier return QR.

```http
POST /api/orders/{public_id}/return-qr/
Authorization: Bearer <courier_access_token>
```

Response shape:

```json
{
  "token": "raw-return-token",
  "expires_at": "...",
  "order_public_id": "uuid",
  "locker_name": "Demo Locker Maadi",
  "locker_code": "DEMO-MAADI-001",
  "locker_address": "Maadi, Cairo, Egypt"
}
```

## 9. Web Admin Dashboard APIs

### 9.1 Dashboard Summary

Screen: Admin dashboard home.

```http
GET /api/lockers/admin/dashboard/
Authorization: Bearer <admin_access_token>
```

Response sections:

- `generated_at`
- `totals`
- `orders_by_status`
- `locker_stations_by_status`
- `drawers_by_status`
- `devices_by_connection_status`
- `notifications_by_delivery_status`
- `action_required`

Recommended dashboard widgets:

- Total orders
- Orders by status
- Drawer utilization
- Locker device health
- Failed notifications
- Expired orders
- Action required summary

### 9.2 Admin Orders List

Screen: Admin orders table.

```http
GET /api/orders/admin/
Authorization: Bearer <admin_access_token>
```

Supported filters:

```http
GET /api/orders/admin/?status=ready_for_pickup
GET /api/orders/admin/?locker_station_id=1
GET /api/orders/admin/?courier_id=3
GET /api/orders/admin/?customer_id=2
GET /api/orders/admin/?search=demo-customer
```

Main fields:

- `public_id`
- `status`
- `total_amount`
- `customer`
- `customer_username`
- `assigned_courier`
- `assigned_courier_username`
- `locker_station`
- `assigned_drawer`
- `assigned_drawer_number`
- `pickup_opened_at`
- `return_opened_at`
- timeline fields
- `items`

### 9.3 Assign Courier

List active couriers for the assignment selector:

```http
GET /api/accounts/admin/couriers/
Authorization: Bearer <admin_access_token>
```

Each item includes profile details plus `is_active`, `is_on_shift`,
`shift_updated_at`, `active_order_count`, and a derived `dispatch_status`
(`inactive`, `off_shift`, `busy`, or `available`). A courier is available only
when active, on shift, and without another open order.

Start or end a courier's shift:

```http
PATCH /api/accounts/admin/couriers/{user_id}/shift/
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

```json
{ "is_on_shift": true }
```

Ending a shift is rejected while the courier has active orders. Shift changes
are written to the audit log. Courier assignment also enforces account status,
shift state, and workload on the backend; the dashboard filter is not a security
boundary. GPS-based proximity matching is not implemented yet.

The courier mobile app reads and changes only its own shift:

```http
GET /api/accounts/couriers/me/shift/
PATCH /api/accounts/couriers/me/shift/
Authorization: Bearer <courier_access_token>
```

```json
{ "is_on_shift": true }
```

The API rejects ending a shift while active orders remain.

### 9.4 Admin People Management

List active and inactive customer, courier, and admin accounts:

```http
GET /api/accounts/admin/users/
Authorization: Bearer <admin_access_token>
```

Create a customer, courier, or admin account. This endpoint is admin-only. Admin accounts receive full dashboard access; locker-device accounts cannot be created through it.

```http
POST /api/accounts/admin/users/
Authorization: Bearer <admin_access_token>
```

```json
{
  "username": "new-courier",
  "password": "A-strong-password",
  "password_confirm": "A-strong-password",
  "first_name": "New",
  "last_name": "Courier",
  "email": "new-courier@example.com",
  "phone": "+201012345678",
  "role": "courier"
}
```

Use `"role": "admin"` only for trusted operators who need full dashboard access.

Disable or reactivate an account without deleting its order history:

```http
PATCH /api/accounts/admin/users/{user_id}/status/
Authorization: Bearer <admin_access_token>
```

```json
{
  "is_active": false
}
```

An admin cannot deactivate their own account, and the last active admin cannot be deactivated.

Account creation and status changes are written to the audit log. Disabled accounts are excluded from the active courier assignment list.

```http
POST /api/orders/{public_id}/assign-courier/
Authorization: Bearer <admin_access_token>
```

Request body:

```json
{
  "courier_id": 3
}
```

### 9.5 Assign Drawer

```http
POST /api/orders/{public_id}/assign/
Authorization: Bearer <admin_access_token>
```

Request body:

```json
{
  "locker_station_id": 1,
  "drawer_id": 1
}
```

### 9.6 Locker Stations

List locker stations:

```http
GET /api/lockers/
```

Eligible pickup stations for a customer's cart:

```http
GET /api/lockers/nearby/?product_ids=1,2&latitude=29.960235&longitude=31.256537
Authorization: Bearer <customer_access_token>
```

Locker detail:

```http
GET /api/lockers/{id}/
```

Create locker station:

```http
POST /api/lockers/admin/stations/
Authorization: Bearer <admin_access_token>
```

Update locker station:

```http
PATCH /api/lockers/admin/stations/{id}/
Authorization: Bearer <admin_access_token>
```

### 9.7 Drawers Management

Create drawer:

```http
POST /api/lockers/admin/stations/{locker_station_id}/drawers/
Authorization: Bearer <admin_access_token>
```

Set drawer maintenance status:

```http
PATCH /api/lockers/admin/drawers/{drawer_id}/maintenance-status/
Authorization: Bearer <admin_access_token>
```

Allowed statuses:

- `available`
- `out_of_service`

### 9.8 Locker Devices

List devices:

```http
GET /api/lockers/admin/devices/
Authorization: Bearer <admin_access_token>
```

Provision device:

```http
POST /api/lockers/admin/stations/{locker_station_id}/device/
Authorization: Bearer <admin_access_token>
```

Activate or deactivate device:

```http
PATCH /api/lockers/admin/devices/{device_id}/activation/
Authorization: Bearer <admin_access_token>
```




### 9.9 Admin Notifications Monitoring

Screen: Admin notification delivery monitoring.

```http
GET /api/notifications/admin/
Authorization: Bearer <admin_access_token>
```

This endpoint is restricted to administrators. It returns notifications for all recipients, including delivery tracking and recipient details.

Supported filters:

```http
GET /api/notifications/admin/?delivery_status=failed
GET /api/notifications/admin/?notification_type=order_ready_for_pickup
GET /api/notifications/admin/?unread=true
```

Admin-only response fields in addition to the standard notification fields:

- `recipient`
- `recipient_username`
- `delivery_status`
- `delivery_attempts`
- `delivered_at`
- `delivery_error`
### 9.10 Audit Log

Screen: Admin audit log.

```http
GET /api/audit/
Authorization: Bearer <admin_access_token>
```

Supported filters:

```http
GET /api/audit/?action=order_courier_assigned
GET /api/audit/?target_type=order
GET /api/audit/?actor_id=1
GET /api/audit/?target_id=<uuid>
```

### 9.11 Admin Product Catalogue

List all products, including inactive products:

```http
GET /api/products/admin/
Authorization: Bearer <admin_access_token>
```

Create products with `POST /api/products/` and edit them with
`PATCH /api/products/{id}/`. Requests may use `multipart/form-data` when
uploading an `image` (JPEG, PNG, or WebP; up to 5 MB). Omit the image field to
keep the current image, or send `clear_image=true` to remove it. Admins can
update the name, category, description, price, stock, parcel size
(`small`, `medium`, `large`), availability, and image. The public product list
continues to return active products only.

## 10. Locker Device APIs

The locker machine can be real hardware, tablet UI, or simulation screen.

### 10.1 Device Heartbeat

```http
POST /api/lockers/device/heartbeat/
Authorization: Bearer <locker_device_access_token>
```

### 10.2 Confirm Package Deposit

```http
POST /api/orders/{public_id}/deposit/
Authorization: Bearer <locker_device_access_token>
Idempotency-Key: <uuid>
```

### 10.3 Customer Pickup Scan

```http
POST /api/lockers/pickup-scan/
Authorization: Bearer <locker_device_access_token>
Idempotency-Key: <uuid>
```

Request body:

```json
{
  "token": "raw-pickup-token"
}
```

Response shape:

```json
{
  "command": "open_drawer",
  "drawer_number": 1,
  "order_public_id": "uuid"
}
```

### 10.4 Confirm Customer Collection

```http
POST /api/lockers/orders/{public_id}/confirm-collection/
Authorization: Bearer <locker_device_access_token>
Idempotency-Key: <uuid>
```

### 10.5 Courier Return Scan

```http
POST /api/lockers/return-scan/
Authorization: Bearer <locker_device_access_token>
Idempotency-Key: <uuid>
```

### 10.6 Confirm Courier Return

```http
POST /api/lockers/orders/{public_id}/confirm-return/
Authorization: Bearer <locker_device_access_token>
Idempotency-Key: <uuid>
```

## 11. Recommended Frontend Build Order

1. Web Admin Dashboard
   - Login
   - Dashboard summary
   - Orders list
   - Order detail
   - Lockers and drawers
   - Device status
   - Notifications/support view
   - Audit log

2. Flutter Customer App
   - Register/login
   - Products
   - Product detail
   - Create order
   - My orders
   - Pickup QR
   - Notifications

3. Flutter Courier App
   - Login
   - Assigned orders
   - Deposit instructions
   - Return orders
   - Return QR

4. Locker Device Simulation
   - Login as locker device
   - Heartbeat
   - Pickup scan
   - Confirm collection
   - Return scan
   - Confirm return

## 12. Notes For The Frontend Team

- Use order `public_id` in URLs, not numeric order IDs.
- Treat QR tokens as sensitive. Do not log them.
- Locker device mutation requests require `Idempotency-Key`.
- Use `/api/accounts/me/` after login to decide which UI to show.
- Refresh access tokens with `/api/token/refresh/`.
- Admin list screens should support pagination.
- Customers usually do not need to see notification `delivery_error`.
- Admin/support screens should show failed notification data.
- OpenAPI docs are available at `/api/docs/` when `API_DOCUMENTATION_ENABLED` is true.
