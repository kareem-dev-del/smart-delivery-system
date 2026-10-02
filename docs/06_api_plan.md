# Smart Delivery System - API Plan

## 1. الهدف من الملف

هذا الملف يحدد endpoints الخاصة بالنظام قبل كتابة الكود.

لكل endpoint نحدد:

- HTTP method.
- URL.
- المستخدم المسموح له.
- الهدف.
- request body.
- response.
- status codes.
- permission.

القاعدة:

```text
No endpoint without a purpose, permission, and expected response.
```

---

## 2. API Groups

سنقسم الـ APIs إلى مجموعات:

```text
Auth APIs
Product APIs
Order APIs
Courier APIs
Locker Machine APIs
Admin APIs
AI Service APIs
```

---

## 3. Auth APIs

### 3.1 Obtain Token

```http
POST /api/token/
```

الهدف:

تسجيل الدخول والحصول على JWT access و refresh tokens.

Permission:

```text
AllowAny
```

Request:

```json
{
  "username": "customer1",
  "password": "password123"
}
```

Success response:

```json
{
  "access": "access-token",
  "refresh": "refresh-token"
}
```

Status codes:

```text
200 OK
401 Unauthorized
```

---

### 3.2 Refresh Token

```http
POST /api/token/refresh/
```

الهدف:

الحصول على access token جديد باستخدام refresh token.

Permission:

```text
AllowAny
```

Request:

```json
{
  "refresh": "refresh-token"
}
```

Success response:

```json
{
  "access": "new-access-token"
}
```

Status codes:

```text
200 OK
401 Unauthorized
```

---

## 4. Product APIs

### 4.1 List Products

```http
GET /api/products/
```

الهدف:

عرض المنتجات المتاحة للعميل.

Permission:

```text
AllowAny
```

Response:

```json
[
  {
    "id": 1,
    "name": "Watch Model A",
    "price": "2500.00",
    "size": "small",
    "stock": 10,
    "is_active": true
  }
]
```

Status codes:

```text
200 OK
```

Notes:

- يجب استخدام pagination لاحقًا.
- لا نعرض المنتجات غير active للعميل.

---

### 4.2 Product Details

```http
GET /api/products/{id}/
```

الهدف:

عرض تفاصيل منتج واحد.

Permission:

```text
AllowAny
```

Status codes:

```text
200 OK
404 Not Found
```

---

### 4.3 Create Product

```http
POST /api/products/
```

الهدف:

إضافة منتج جديد.

Permission:

```text
Admin only
```

Request:

```json
{
  "name": "Watch Model A",
  "description": "Smart watch",
  "price": "2500.00",
  "stock": 10,
  "size": "small",
  "is_active": true
}
```

Status codes:

```text
201 Created
400 Bad Request
401 Unauthorized
403 Forbidden
```

---

### 4.4 Update Product

```http
PATCH /api/products/{id}/
```

Permission:

```text
Admin only
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
```

---

## 5. Locker APIs

### 5.1 List Locker Stations

```http
GET /api/lockers/
```

الهدف:

عرض lockers المتاحة.

Permission:

```text
Authenticated users
```

Response:

```json
[
  {
    "id": 1,
    "name": "Mall Locker",
    "code": "LOCKER-001",
    "address": "Main Mall",
    "status": "online"
  }
]
```

Status codes:

```text
200 OK
401 Unauthorized
```

---

### 5.2 Locker Details

```http
GET /api/lockers/{id}/
```

Permission:

```text
Authenticated users
```

Status codes:

```text
200 OK
401 Unauthorized
404 Not Found
```

---

### 5.3 Admin Create Locker

```http
POST /api/admin/lockers/
```

Permission:

```text
Admin only
```

Request:

```json
{
  "name": "Mall Locker",
  "code": "LOCKER-001",
  "address": "Main Mall",
  "latitude": 30.123,
  "longitude": 31.456,
  "status": "online"
}
```

Status codes:

```text
201 Created
400 Bad Request
401 Unauthorized
403 Forbidden
```

---

### 5.4 Admin Create Drawer

```http
POST /api/admin/drawers/
```

Permission:

```text
Admin only
```

Request:

```json
{
  "locker_station": 1,
  "number": 3,
  "size": "medium",
  "status": "available"
}
```

Status codes:

```text
201 Created
400 Bad Request
401 Unauthorized
403 Forbidden
```

---

## 6. AI Recommendation APIs

### 6.1 Recommend Locker Through Django

```http
POST /api/lockers/recommend/
```

الهدف:

العميل يطلب recommendation من Django. Django يجمع بيانات lockers ويرسلها إلى FastAPI AI service.

Permission:

```text
Authenticated customer
```

Request:

```json
{
  "customer_location": {
    "lat": 30.123,
    "lng": 31.456
  },
  "order_size": "medium"
}
```

Response:

```json
{
  "recommended_locker": {
    "id": 1,
    "name": "Mall Locker",
    "code": "LOCKER-001"
  },
  "score": 88,
  "reason": "Nearest online locker with an available medium drawer",
  "used_fallback": false
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
```

Notes:

- هذا endpoint يمر من Django وليس من الموبايل إلى FastAPI مباشرة.
- إذا AI service فشل، يستخدم Django fallback.

---

### 6.2 FastAPI Internal Recommendation Endpoint

```http
POST /ai/recommend-locker/
```

الهدف:

Endpoint داخلي في FastAPI AI service.

Caller:

```text
Django backend only
```

Request:

```json
{
  "customer_location": {
    "lat": 30.123,
    "lng": 31.456
  },
  "order_size": "medium",
  "available_lockers": [
    {
      "id": 1,
      "name": "Mall Locker",
      "lat": 30.120,
      "lng": 31.450,
      "status": "online",
      "available_drawers": {
        "small": 2,
        "medium": 1,
        "large": 0
      }
    }
  ]
}
```

Response:

```json
{
  "recommended_locker_id": 1,
  "score": 88,
  "reason": "Nearest online locker with an available medium drawer"
}
```

Status codes:

```text
200 OK
400 Bad Request
```

---

## 7. Order APIs

### 7.1 Create Order

```http
POST /api/orders/
```

الهدف:

إنشاء order جديد.

Permission:

```text
Authenticated customer
```

Request:

```json
{
  "items": [
    {
      "product_id": 1,
      "quantity": 1
    }
  ],
  "selected_locker": 1
}
```

Success response:

```json
{
  "id": 10,
  "status": "Pending",
  "selected_locker": 1,
  "total_price": "2500.00"
}
```

Status codes:

```text
201 Created
400 Bad Request
401 Unauthorized
403 Forbidden
```

Notes:

- customer فقط يستطيع إنشاء order.
- stock يجب أن يكون كافيًا.
- selected_locker يمكن أن يأتي من AI recommendation.

---

### 7.2 My Orders

```http
GET /api/orders/my/
```

الهدف:

عرض طلبات العميل الحالي فقط.

Permission:

```text
Authenticated customer
```

Status codes:

```text
200 OK
401 Unauthorized
403 Forbidden
```

---

### 7.3 Order Details

```http
GET /api/orders/{id}/
```

الهدف:

عرض تفاصيل order.

Permission:

```text
Owner customer, assigned courier, or admin
```

Status codes:

```text
200 OK
401 Unauthorized
403 Forbidden
404 Not Found
```

---

### 7.4 Get Pickup QR

```http
GET /api/orders/{id}/pickup-qr/
```

الهدف:

الحصول على QR token لاستلام الطلب.

Permission:

```text
Order owner customer only
```

Rules:

- order status يجب أن يكون `Ready_For_Pickup`.
- QR له expiration.

Response:

```json
{
  "qr_token": "secure-token",
  "expires_at": "2026-09-25T10:00:00Z"
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
```

---

## 8. Courier APIs

### 8.1 Courier Assigned Orders

```http
GET /api/courier/orders/
```

الهدف:

عرض الطلبات المخصصة للمندوب الحالي.

Permission:

```text
Authenticated courier
```

Status codes:

```text
200 OK
401 Unauthorized
403 Forbidden
```

---

### 8.2 Generate Deposit QR

```http
POST /api/courier/orders/{id}/generate-deposit-qr/
```

الهدف:

توليد QR للمندوب حتى يضع الطلب في الدرج.

Permission:

```text
Assigned courier only
```

Rules:

- order يجب أن يكون assigned لهذا المندوب.
- order status يسمح بالإيداع.

Response:

```json
{
  "qr_token": "secure-token",
  "expires_at": "2026-09-23T13:00:00Z"
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
```

---

### 8.3 Confirm Deposit

```http
POST /api/courier/orders/{id}/confirm-deposit/
```

الهدف:

تأكيد أن المندوب وضع الطلب داخل الدرج.

Permission:

```text
Assigned courier only
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
```

Notes:

- في النسخة النهائية، التأكيد الأفضل يأتي من `drawer-closed` event.
- في الـ MVP يمكن استخدام هذا endpoint للديمو.

---

## 9. Locker Machine APIs

### 9.1 Scan QR

```http
POST /api/locker/scan/
```

الهدف:

الماكينة ترسل QR token إلى Django للتحقق وفتح الدرج الصحيح.

Permission:

```text
Locker device only
```

Request:

```json
{
  "machine_id": "LOCKER-001",
  "qr_token": "secure-token"
}
```

Success response:

```json
{
  "action": "open_drawer",
  "drawer_number": 3,
  "message": "QR accepted"
}
```

Error response:

```json
{
  "action": "reject",
  "message": "Invalid or expired QR"
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
409 Conflict
```

Notes:

- لا يتم استدعاء AI service هنا.
- هذا endpoint يجب أن يكون سريعًا.

---

### 9.2 Drawer Closed

```http
POST /api/locker/drawer-closed/
```

الهدف:

إبلاغ backend أن الدرج تم قفله بعد الإيداع أو الاستلام.

Permission:

```text
Locker device only
```

Request:

```json
{
  "machine_id": "LOCKER-001",
  "drawer_number": 3,
  "order_id": 10
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
```

---

### 9.3 Heartbeat

```http
POST /api/locker/heartbeat/
```

الهدف:

الماكينة ترسل إشارة أنها online.

Permission:

```text
Locker device only
```

Request:

```json
{
  "machine_id": "LOCKER-001"
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
```

---

## 10. Admin APIs

في الـ MVP سنعتمد بشكل أساسي على Django Admin.

لكن يمكن إضافة endpoints عند الحاجة.

---

### 10.1 Assign Courier

```http
POST /api/admin/orders/{id}/assign-courier/
```

الهدف:

تعيين مندوب للطلب.

Permission:

```text
Admin only
```

Request:

```json
{
  "courier_id": 5
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
```

---

### 10.2 Emergency Open Drawer

```http
POST /api/admin/drawers/{id}/emergency-open/
```

الهدف:

فتح درج للطوارئ.

Permission:

```text
Admin only
```

Request:

```json
{
  "reason": "Customer support case"
}
```

Status codes:

```text
200 OK
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
```

Notes:

- يجب إنشاء event log.
- reason مطلوب.

---

## 11. Status Code Rules

### 200 OK

الطلب نجح بدون إنشاء resource جديد.

### 201 Created

تم إنشاء resource جديد.

### 400 Bad Request

البيانات غير صحيحة أو حالة الطلب لا تسمح بالعملية.

### 401 Unauthorized

لا يوجد token أو token غير صحيح.

### 403 Forbidden

المستخدم معروف لكن ليس لديه صلاحية.

### 404 Not Found

العنصر غير موجود أو غير متاح لهذا المستخدم.

### 409 Conflict

تعارض في الحالة، مثل QR مستخدم من قبل أو drawer مشغول.

---

## 12. API Security Rules

- كل endpoint حساس يحتاج authentication.
- كل endpoint يحتاج permission واضحة.
- customer لا يرى orders غيره.
- courier لا يرى orders غير المخصصة له.
- locker device لا يستخدم JWT الخاص بالمستخدمين.
- QR validation في Django فقط.
- AI service لا يستقبل user access token.
- AI service لا يفتح drawer.

---

## 13. Definition of Done

API plan يعتبر جاهزًا إذا:

- كل endpoint مهم مكتوب.
- كل endpoint له permission.
- request/response معروف.
- status codes محددة.
- AI service endpoints منفصلة وواضحة.
- locker machine endpoints واضحة.
- نقدر نبدأ تنفيذ Django views بناء على هذا الملف.

