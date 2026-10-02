# Smart Delivery System - Requirements

## 1. الهدف من الملف

هذا الملف يحول فكرة المشروع والـ MVP إلى متطلبات واضحة يمكن تنفيذها واختبارها.

أي feature سنبنيها لاحقًا يجب أن ترجع إلى requirement واضح في هذا الملف.

الهدف:

```text
No random coding.
Every feature has a reason, user, permission, and expected result.
```

---

## 2. أنواع المستخدمين

### 2.1 Customer

العميل الذي يطلب المنتج ويستلم الطلب من الـ smart locker.

مسؤولياته:

- تسجيل الدخول.
- رؤية المنتجات.
- إنشاء order.
- رؤية طلباته فقط.
- استلام pickup QR.
- استلام الطلب من الدرج.

---

### 2.2 Courier

المندوب المسؤول عن وضع الطلب داخل الدرج.

مسؤولياته:

- تسجيل الدخول.
- رؤية الطلبات المخصصة له فقط.
- الحصول على deposit QR.
- وضع الطلب داخل الدرج الصحيح.
- تأكيد عملية الإيداع.

---

### 2.3 Admin

مسؤول النظام أو الشركة.

مسؤولياته:

- إدارة المنتجات.
- إدارة الطلبات.
- إدارة المندوبين.
- إدارة الـ lockers.
- إدارة الأدراج.
- رؤية event logs.
- تنفيذ emergency unlock عند الحاجة.

---

### 2.4 Locker Machine

الماكينة التي تحتوي على الأدراج.

مسؤولياتها:

- قراءة QR token.
- إرسال QR token إلى الـ backend.
- استقبال أمر فتح درج معين.
- إرسال حالة الدرج بعد الفتح أو القفل.
- إرسال heartbeat لتأكيد أنها تعمل.

---

## 3. Functional Requirements

Functional Requirements هي المتطلبات التي تصف ماذا يجب أن يفعل النظام.

---

### Authentication & Users

#### FR-001: User Login

النظام يجب أن يسمح للمستخدم بتسجيل الدخول باستخدام username/password.

Expected result:

```text
access token + refresh token
```

---

#### FR-002: Token Refresh

النظام يجب أن يسمح للمستخدم بالحصول على access token جديد باستخدام refresh token.

---

#### FR-003: User Roles

كل user يجب أن يكون له role واضح:

```text
customer
courier
admin
locker_device
```

---

#### FR-004: Role-Based Access

النظام يجب أن يمنع أي user من تنفيذ عملية ليست من صلاحياته.

مثال:

```text
Customer cannot access courier orders.
Courier cannot manage products.
Locker device cannot access admin dashboard.
```

---

### Products

#### FR-005: View Products

العميل يجب أن يستطيع رؤية المنتجات المتاحة.

---

#### FR-006: View Product Details

العميل يجب أن يستطيع رؤية تفاصيل منتج معين.

---

#### FR-007: Admin Manage Products

الأدمن يجب أن يستطيع إضافة وتعديل وتعطيل المنتجات.

Product fields:

```text
name
description
price
stock
size
is_active
```

---

### Orders

#### FR-008: Customer Create Order

العميل يجب أن يستطيع إنشاء order من منتج أو أكثر.

Rules:

- المستخدم يجب أن يكون authenticated.
- المستخدم يجب أن يكون customer.
- المنتجات يجب أن تكون active.
- stock يجب أن يكون كافيًا.

Expected status:

```text
201 Created
```

---

#### FR-009: Customer View Own Orders

العميل يجب أن يرى طلباته فقط.

ممنوع أن يرى طلبات عميل آخر.

---

#### FR-010: Admin View All Orders

الأدمن يجب أن يرى كل الطلبات.

---

#### FR-011: Courier View Assigned Orders

المندوب يجب أن يرى الطلبات المخصصة له فقط.

---

#### FR-012: Order Status Tracking

كل order يجب أن يكون له status واضح.

Statuses في الـ MVP:

```text
Pending
Assigned_To_Courier
Ready_For_Deposit
Stored_In_Locker
Ready_For_Pickup
Picked_Up
Cancelled
Expired
```

---

### Lockers & Drawers

#### FR-013: Admin Manage Locker Stations

الأدمن يجب أن يستطيع إضافة وتعديل locker stations.

LockerStation fields:

```text
name
code
address
latitude
longitude
status
```

---

#### FR-014: Admin Manage Drawers

الأدمن يجب أن يستطيع إدارة الأدراج داخل كل locker.

Drawer fields:

```text
locker_station
number
size
status
current_order
```

Drawer sizes:

```text
small
medium
large
```

Drawer statuses:

```text
available
reserved
occupied
out_of_service
```

---

#### FR-015: Drawer Selection

النظام يجب أن يختار drawer مناسب لحجم الطلب.

Rules:

- drawer يجب أن يكون available.
- drawer size يجب أن يناسب order size.
- drawer لا يجب أن يكون out_of_service.

---

### AI Locker Recommendation

#### FR-016: Recommend Best Locker

النظام يجب أن يقترح أفضل locker للعميل عند إنشاء order أو اختيار مكان الاستلام.

Recommendation factors:

- قرب الـ locker من العميل.
- وجود drawer متاح.
- drawer مناسب لحجم الطلب.
- locker status.
- نسبة الامتلاء.

---

#### FR-017: AI Service Endpoint

FastAPI AI service يجب أن يوفر endpoint:

```http
POST /ai/recommend-locker/
```

ويرجع:

```json
{
  "recommended_locker_id": 1,
  "score": 88,
  "reason": "Nearest online locker with an available medium drawer"
}
```

---

#### FR-018: AI Fallback

إذا فشل AI service، يجب أن يستخدم Django fallback بسيط.

Fallback rule:

```text
Choose nearest online locker with suitable available drawer.
```

السبب:

إنشاء الطلب لا يجب أن يفشل بالكامل بسبب توقف خدمة الـ AI.

---

### QR Tokens

#### FR-019: Generate Deposit QR

النظام يجب أن يسمح للمندوب بتوليد deposit QR للطلب المخصص له.

Rules:

- المستخدم يجب أن يكون courier.
- الطلب يجب أن يكون assigned لهذا المندوب.
- QR token له expiration.

---

#### FR-020: Generate Pickup QR

النظام يجب أن يسمح للعميل بالحصول على pickup QR عندما يكون الطلب جاهزًا للاستلام.

Rules:

- المستخدم يجب أن يكون صاحب الطلب.
- order status يجب أن يكون `Ready_For_Pickup`.
- QR token له expiration.

---

#### FR-021: QR Token Validation

النظام يجب أن يتحقق من QR token قبل فتح أي درج.

Validation rules:

- token صحيح.
- token لم يستخدم من قبل.
- token لم تنته صلاحيته.
- token مرتبط بالـ order الصحيح.
- order status يسمح بالعملية.

---

#### FR-022: QR Single Use

كل QR token يجب أن يستخدم مرة واحدة فقط.

بعد الاستخدام:

```text
used_at must be set
```

---

### Locker Machine APIs

#### FR-023: Locker Scan QR

الماكينة يجب أن ترسل QR token إلى الـ backend عند scan.

Endpoint:

```http
POST /api/locker/scan/
```

Request:

```json
{
  "machine_id": "LOCKER-001",
  "qr_token": "secure-token"
}
```

---

#### FR-024: Open Correct Drawer

إذا كان QR صحيحًا، يجب أن يرجع الـ backend رقم الدرج الصحيح للماكينة.

Response:

```json
{
  "action": "open_drawer",
  "drawer_number": 3
}
```

---

#### FR-025: Reject Invalid QR

إذا كان QR غير صالح، لا يجب فتح أي درج.

Expected status:

```text
400 Bad Request
```

أو:

```text
403 Forbidden
```

حسب سبب الرفض.

---

#### FR-026: Drawer Closed Event

الماكينة يجب أن تبلغ الـ backend عندما يتم قفل الدرج.

Endpoint:

```http
POST /api/locker/drawer-closed/
```

---

#### FR-027: Locker Heartbeat

الماكينة يجب أن ترسل heartbeat للـ backend للتأكيد أنها online.

Endpoint:

```http
POST /api/locker/heartbeat/
```

---

### Event Logs

#### FR-028: Log Important Events

النظام يجب أن يسجل الأحداث المهمة.

Events:

```text
order_created
locker_recommended
deposit_qr_generated
pickup_qr_generated
qr_scanned
drawer_opened
drawer_closed
order_stored
order_picked_up
invalid_qr
expired_qr
emergency_open
```

---

#### FR-029: Admin View Logs

الأدمن يجب أن يستطيع رؤية event logs من dashboard.

---

### Admin

#### FR-030: Admin Dashboard

الأدمن يجب أن يستخدم Django Admin لإدارة البيانات الأساسية في الـ MVP.

---

#### FR-031: Emergency Unlock

الأدمن يجب أن يستطيع فتح درج للطوارئ.

Rules:

- admin only.
- reason required.
- event log must be created.

---

## 4. Non-Functional Requirements

Non-Functional Requirements تصف جودة النظام، مثل الأمان والأداء والقابلية للتوسع.

---

### Security

#### NFR-001: HTTPS in Production

في production يجب أن يعمل النظام عبر HTTPS.

---

#### NFR-002: No Secrets in Code

لا يجب وضع secrets أو tokens أو passwords داخل الكود.

يجب استخدام environment variables.

---

#### NFR-003: QR Must Not Expose Drawer Number

الـ QR لا يجب أن يحتوي على drawer number أو order id بشكل مكشوف.

الـ QR يجب أن يحتوي على secure token فقط.

---

#### NFR-004: Backend Controls Drawer Opening

الماكينة لا يجب أن تفتح درج إلا بعد موافقة الـ backend.

---

#### NFR-005: Role Isolation

كل role يجب أن يرى البيانات الخاصة به فقط.

---

### Performance

#### NFR-006: Pagination

أي endpoint يعرض list كبيرة يجب أن يستخدم pagination.

مثال:

```text
products
orders
event logs
```

---

#### NFR-007: Query Optimization

يجب استخدام `select_related` و `prefetch_related` عند الحاجة لتقليل عدد database queries.

---

#### NFR-008: Fast Locker Scan Response

استجابة locker scan يجب أن تكون سريعة لأن العميل واقف أمام الماكينة.

Target في الـ MVP:

```text
Under 2 seconds in local/demo environment
```

---

### Scalability

#### NFR-009: Modular Code

الكود يجب أن يكون منظمًا بحيث يمكن تطويره لاحقًا.

مثال:

- permissions منفصلة.
- business logic في services عند الحاجة.
- AI service منفصل.

---

#### NFR-010: AI Service Is Independent

FastAPI AI service يجب أن تكون قابلة للتشغيل منفصلة عن Django.

---

#### NFR-011: Fallback When AI Fails

Django يجب أن يملك fallback إذا توقفت خدمة AI.

---

### Reliability

#### NFR-012: Event Logging

كل عملية حساسة يجب أن تسجل في event logs.

---

#### NFR-013: Idempotency for QR Use

استخدام QR أكثر من مرة لا يجب أن يفتح الدرج مرة أخرى.

---

### Maintainability

#### NFR-014: Tests Required

أي feature أمنية أو أساسية يجب أن يكون لها test.

---

#### NFR-015: Documentation Required

كل endpoint مهم يجب توثيقه.

---

## 5. Business Rules

### BR-001: Customer Can Only Access Own Orders

العميل لا يرى إلا طلباته.

---

### BR-002: Courier Can Only Access Assigned Orders

المندوب لا يرى إلا الطلبات المخصصة له.

---

### BR-003: One Drawer Holds One Order

في الـ MVP، كل drawer يحتوي على order واحد فقط.

---

### BR-004: QR Expires

كل QR token له وقت انتهاء.

اقتراح:

```text
Deposit QR: 2 hours
Pickup QR: 48 hours
```

---

### BR-005: Pickup QR Works Only When Order Is Ready

pickup QR لا يعمل إلا إذا كان order status:

```text
Ready_For_Pickup
```

---

### BR-006: Offline Locker Cannot Be Recommended

أي locker status = offline لا يجب أن يتم اقتراحه من AI service.

---

### BR-007: Full Locker Cannot Be Selected

إذا لم يوجد drawer مناسب، لا يجب اختيار locker.

---

## 6. User Stories

### US-001: Customer Creates Order

```text
As a customer,
I want to create an order from the mobile app,
so that I can receive my product through a smart locker.
```

Acceptance Criteria:

- customer must be authenticated.
- product must be active.
- order must be created with status `Pending`.

---

### US-002: Customer Gets Recommended Locker

```text
As a customer,
I want the system to recommend a suitable locker,
so that I can pick up my order from a convenient location.
```

Acceptance Criteria:

- recommended locker must be online.
- recommended locker must have suitable available drawer.
- response must include reason.

---

### US-003: Courier Deposits Order

```text
As a courier,
I want to deposit an assigned order into a smart locker,
so that the customer can pick it up later.
```

Acceptance Criteria:

- courier can access assigned order only.
- deposit QR opens correct drawer.
- event log is created.

---

### US-004: Customer Picks Up Order

```text
As a customer,
I want to scan a QR code at the locker,
so that I can open the drawer and pick up my order.
```

Acceptance Criteria:

- pickup QR must be valid.
- drawer opens only once.
- order status becomes `Picked_Up`.

---

### US-005: Admin Monitors System

```text
As an admin,
I want to see orders, lockers, drawers, and event logs,
so that I can manage and troubleshoot the system.
```

Acceptance Criteria:

- admin can view all orders.
- admin can view event logs.
- admin can perform emergency unlock with reason.

---

## 7. Important Status Codes

```text
200 OK
```

الطلب نجح.

```text
201 Created
```

تم إنشاء resource جديد.

```text
400 Bad Request
```

البيانات المرسلة غير صحيحة.

```text
401 Unauthorized
```

لا يوجد authentication صحيح.

```text
403 Forbidden
```

المستخدم معروف لكن ليس لديه صلاحية.

```text
404 Not Found
```

العنصر غير موجود.

```text
409 Conflict
```

تعارض، مثل محاولة استخدام QR مستخدم من قبل.

---

## 8. Definition of Done

نعتبر requirements هذه جاهزة للتنفيذ إذا:

- كل user له دور واضح.
- كل feature أساسية لها FR واضح.
- قواعد الأمان مكتوبة.
- قواعد الـ QR مكتوبة.
- AI recommendation محددة بوضوح.
- status codes المهمة محددة.
- user stories مكتوبة.

