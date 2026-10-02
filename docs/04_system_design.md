# Smart Delivery System - System Design

## 1. الهدف من الملف

هذا الملف يشرح تصميم النظام قبل كتابة الكود.

الهدف هو أن نعرف:

- مكونات النظام.
- مسؤولية كل مكون.
- كيف تتواصل المكونات مع بعضها.
- أين يوجد الأمان.
- أين نضع الـ AI.
- كيف نتجنب التعقيد الزائد.

القاعدة:

```text
Design first, code second.
```

---

## 2. الصورة العامة للنظام

النظام يتكون من خمسة أجزاء رئيسية:

```text
Mobile App
Django REST API
FastAPI AI Service
PostgreSQL Database
Locker Machine / Simulation
```

الشكل العام:

```text
                 +------------------+
                 |    Mobile App    |
                 | Customer/Courier |
                 +---------+--------+
                           |
                           | HTTPS + JWT
                           v
                 +------------------+
                 | Django REST API  |
                 |   Core Backend   |
                 +----+--------+----+
                      |        |
       SQL            |        | Internal HTTP
                      v        v
          +----------------+  +---------------------+
          |   PostgreSQL   |  | FastAPI AI Service  |
          |    Database    |  | Locker Recommendation|
          +----------------+  +---------------------+
                      ^
                      |
                      | HTTPS + Device Token
                      |
             +--------+---------+
             | Locker Machine   |
             | or Simulation    |
             +------------------+
```

---

## 3. مسؤولية كل جزء

### 3.1 Mobile App

في أول مرحلة لن نبني frontend كامل، لكن النظام مصمم له.

مسؤولياته لاحقًا:

- تسجيل دخول العميل والمندوب.
- عرض المنتجات.
- إنشاء order.
- عرض recommended locker.
- عرض pickup QR.
- عرض طلبات المندوب.

ملاحظة:

أثناء تطوير backend سنستخدم API client أو `.http` files بدل frontend كامل.

---

### 3.2 Django REST API

Django هو قلب النظام.

مسؤولياته:

- Authentication.
- Authorization.
- Users and roles.
- Products.
- Orders.
- Lockers.
- Drawers.
- QR tokens.
- Locker scan validation.
- Event logs.
- Admin dashboard.
- التواصل مع AI service.

قاعدة مهمة:

```text
أي قرار أمني يبقى داخل Django.
```

يعني Django هو الذي يقرر:

- هل المستخدم مسموح له؟
- هل QR صالح؟
- هل الدرج يفتح؟
- هل order status يسمح بالعملية؟

---

### 3.3 FastAPI AI Service

FastAPI AI service مسؤول فقط عن القرار الذكي الخاص باقتراح أفضل locker.

مسؤولياته في الـ MVP:

- استقبال بيانات العميل والطلب والـ lockers المتاحة.
- حساب score لكل locker.
- إرجاع أفضل locker مع السبب.

لا يفعل:

- لا يفتح drawer.
- لا يتحقق من QR.
- لا يغير order status.
- لا يدخل على database مباشرة في أول نسخة.
- لا يملك صلاحيات admin.

السبب:

نريد AI service يساعد في القرار، لكن لا يتحكم في العمليات الأمنية.

---

### 3.4 PostgreSQL Database

PostgreSQL هي قاعدة البيانات الرئيسية.

سيتم تخزين:

- users.
- products.
- orders.
- lockers.
- drawers.
- QR tokens.
- event logs.
- AI recommendation logs.

في أول نسخة:

```text
Django فقط يتعامل مباشرة مع database.
```

FastAPI AI service يستقبل البيانات من Django ولا يقرأ database مباشرة.

---

### 3.5 Locker Machine / Simulation

الماكينة أو الـ simulation لا يقرران فتح الدرج من نفسهما.

مسؤولياتهما:

- قراءة QR.
- إرسال QR token إلى Django.
- استقبال أمر فتح drawer.
- تنفيذ فتح drawer.
- إرسال drawer closed event.
- إرسال heartbeat.

قاعدة:

```text
Locker Machine is a device executor, not a business decision maker.
```

يعني الماكينة تنفذ فقط قرار الـ backend.

---

## 4. لماذا Django + FastAPI؟

### لماذا Django للـ Core Backend؟

لأن المشروع فيه:

- database كثيرة العلاقات.
- admin dashboard.
- users and permissions.
- orders.
- business rules.
- tests.

Django قوي جدًا في هذه الأشياء.

### لماذا FastAPI للـ AI؟

لأن FastAPI مناسب لخدمات صغيرة وسريعة ومستقلة مثل:

- recommendation service.
- ML model endpoint لاحقًا.
- scoring logic.

هذا يجعل AI قابلًا للتطوير بشكل مستقل بدون تعقيد core backend.

---

## 5. لماذا لا نقسم كل شيء Microservices؟

تقسيم كل شيء من البداية سيجعل المشروع أصعب:

- deployment أكثر.
- debugging أصعب.
- authentication بين خدمات أكثر.
- احتمالية فشل أعلى.
- logging ومراقبة أعقد.

لذلك القرار:

```text
Modular Django backend + one FastAPI AI microservice
```

هذا تصميم عملي ومناسب للـ MVP وسوق العمل.

---

## 6. Django Modules

داخل Django، نقسم المشروع إلى modules أو apps منطقية.

اقتراح مبدئي:

```text
accounts
products
orders
lockers
qr_codes
events
ai_integration
```

### accounts

مسؤول عن:

- users.
- roles.
- permissions.
- auth helpers.

### products

مسؤول عن:

- products.
- stock.
- product size.

### orders

مسؤول عن:

- orders.
- order items.
- order status.
- customer orders.
- courier assigned orders.

### lockers

مسؤول عن:

- locker stations.
- drawers.
- drawer status.
- locker machine endpoints.

### qr_codes

مسؤول عن:

- deposit QR.
- pickup QR.
- token generation.
- token validation.
- expiration.
- single-use logic.

### events

مسؤول عن:

- event logs.
- audit trail.

### ai_integration

مسؤول عن:

- التواصل مع FastAPI AI service.
- fallback recommendation.
- AIRecommendationLog.

---

## 7. Communication Design

### 7.1 Mobile App -> Django

طريقة الاتصال:

```text
HTTPS REST API
JWT Authentication
```

مثال:

```http
Authorization: Bearer <access_token>
```

---

### 7.2 Django -> FastAPI AI Service

طريقة الاتصال:

```text
Internal HTTP request
```

Django يرسل:

- customer location.
- order size.
- available lockers.
- available drawers.

FastAPI يرجع:

- recommended locker id.
- score.
- reason.

إذا AI service فشل، Django يستخدم fallback.

---

### 7.3 Locker Machine -> Django

طريقة الاتصال:

```text
HTTPS REST API
Device Token or API Key
```

الماكينة ترسل:

- machine_id.
- qr_token.

Django يرجع:

- open drawer.
- drawer number.
- error message.

---

## 8. أهم Flows في النظام

### 8.1 Create Order Flow

```text
Customer -> Django -> Products/Stock validation
Customer -> Django -> Get available lockers
Django -> FastAPI AI Service -> Recommend best locker
FastAPI -> Django -> Recommendation result
Django -> Database -> Save order and recommendation log
Django -> Customer -> Order created
```

لو AI service وقع:

```text
Django uses fallback recommendation
```

---

### 8.2 Courier Deposit Flow

```text
Courier -> Django -> Request deposit QR
Django -> Validate courier permission
Django -> Generate deposit QR
Courier -> Locker Machine -> Scan deposit QR
Locker Machine -> Django -> Validate QR
Django -> Check order status
Django -> Choose drawer
Django -> Locker Machine -> Open drawer
Locker Machine -> Django -> Drawer closed
Django -> Update order status
Django -> Event log
```

---

### 8.3 Customer Pickup Flow

```text
Customer -> Django -> Request pickup QR
Django -> Validate customer owns order
Django -> Generate pickup QR
Customer -> Locker Machine -> Scan pickup QR
Locker Machine -> Django -> Validate QR
Django -> Check order status
Django -> Locker Machine -> Open drawer
Locker Machine -> Django -> Drawer closed
Django -> Update order status to Picked_Up
Django -> Event log
```

---

## 9. Security Boundaries

### 9.1 User Security

- كل user له role.
- كل endpoint له permission.
- customer يرى بياناته فقط.
- courier يرى الطلبات المخصصة له فقط.
- admin فقط يدير النظام.

---

### 9.2 QR Security

- QR لا يحتوي على drawer number.
- QR لا يحتوي على order id بشكل مكشوف.
- QR يحتوي على secure token.
- QR له expiration.
- QR يستخدم مرة واحدة فقط.
- QR validation داخل Django فقط.

---

### 9.3 Locker Security

- الماكينة لا تفتح درج بدون موافقة backend.
- كل ماكينة لها machine_id.
- كل ماكينة تستخدم device token أو API key.
- كل open drawer event يتسجل.

---

### 9.4 AI Security

- AI service لا يملك صلاحية فتح درج.
- AI service لا يتحقق من QR.
- AI service لا يغير order status.
- AI service لا يستقبل access token الخاص بالعميل.
- Django يرسل له فقط البيانات المطلوبة للتوصية.

---

## 10. Performance Considerations

### 10.1 API Performance

- استخدام pagination للـ list endpoints.
- استخدام `select_related` للعلاقات المباشرة.
- استخدام `prefetch_related` للعلاقات المتعددة.
- عدم إرسال بيانات غير مطلوبة في response.

### 10.2 Locker Scan Performance

locker scan يجب أن يكون سريعًا.

الهدف في الديمو:

```text
Response under 2 seconds
```

لذلك:

- QR validation يجب أن يكون مباشر.
- لا نستدعي AI service أثناء scan QR.
- لا ننفذ عمليات ثقيلة وقت فتح الدرج.

### 10.3 AI Performance

AI recommendation يحدث عند إنشاء order أو اختيار locker، وليس وقت فتح الدرج.

السبب:

فتح الدرج عملية حساسة ولا يجب تعطيلها بحسابات AI.

---

## 11. Scalability Considerations

التصميم يسمح بالتوسع لاحقًا:

- يمكن نشر AI service منفصلًا.
- يمكن إضافة Celery للمهام الخلفية.
- يمكن إضافة Redis للـ cache.
- يمكن إضافة أكثر من locker machine.
- يمكن إضافة أكثر من courier.
- يمكن تطوير recommendation إلى ML model.

لكن في الـ MVP نبدأ بسيطًا:

```text
Django + PostgreSQL + FastAPI AI Service
```

---

## 12. Failure Handling

### AI Service Down

الحل:

```text
Django fallback recommendation
```

### Locker Offline

الحل:

```text
Do not recommend offline locker.
Show machine unavailable.
```

### Invalid QR

الحل:

```text
Reject request.
Do not open drawer.
Create event log.
```

### Drawer Does Not Close

الحل:

```text
Keep order status pending confirmation.
Create warning event.
Admin can investigate.
```

---

## 13. MVP Architecture Decision Record

### Decision 1

استخدام Django REST Framework كـ core backend.

Reason:

مناسب للـ users, permissions, database, admin dashboard.

---

### Decision 2

استخدام FastAPI كـ AI microservice فقط.

Reason:

يعزل AI recommendation ويجعلها قابلة للتطوير لاحقًا.

---

### Decision 3

عدم استخدام microservices لكل النظام في البداية.

Reason:

تقليل التعقيد والتركيز على MVP قوي.

---

### Decision 4

عدم استدعاء AI service عند scan QR.

Reason:

فتح الدرج يجب أن يكون سريعًا وآمنًا.

---

### Decision 5

استخدام simulation قبل hardware الحقيقي.

Reason:

إثبات الفلو كامل حتى لو الهاردوير تأخر.

---

## 14. Definition of Done

هذه الخطوة تعتبر مكتملة عندما:

- مكونات النظام واضحة.
- مسؤولية Django واضحة.
- مسؤولية FastAPI AI service واضحة.
- مسؤولية Locker Machine واضحة.
- أهم flows مكتوبة.
- security boundaries مكتوبة.
- performance considerations مكتوبة.
- failure handling مكتوب.

