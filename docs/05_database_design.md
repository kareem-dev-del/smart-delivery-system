# Smart Delivery System - Database Design

## 1. الهدف من الملف

هذا الملف يحدد تصميم قاعدة البيانات قبل كتابة Django models.

الهدف:

- نعرف كل جدول مسؤول عن إيه.
- نعرف العلاقات بين الجداول.
- نحدد أهم fields.
- نحدد status values.
- نحدد constraints المهمة للأمان والمنطق.

القاعدة:

```text
Good database design makes APIs easier and safer.
```

---

## 2. الجداول الأساسية

الجداول المطلوبة في الـ MVP:

```text
User
UserProfile
Product
Order
OrderItem
LockerStation
Drawer
QRToken
LockerEventLog
AIRecommendationLog
```

---

## 3. ERD مبسط

```text
User
  |
  | 1-1
  v
UserProfile

User (customer) 1----* Order
User (courier)  1----* Order

Order 1----* OrderItem
Product 1----* OrderItem

LockerStation 1----* Drawer
LockerStation 1----* Order
Drawer 1----* Order

Order 1----* QRToken
Order 1----* LockerEventLog
Order 1----* AIRecommendationLog
```

ملاحظة:

العلاقة بين `Drawer` و `Order` في الـ MVP ستكون:

```text
كل order يمكن أن يكون له drawer واحد
كل drawer يمكن أن يحتوي order واحد حاليًا
```

---

## 4. User

سنستخدم Django built-in User في البداية.

السبب:

- جاهز.
- مدعوم في Django Admin.
- يعمل مع authentication.
- مناسب للـ MVP.

لا نبدأ بـ custom user إلا إذا احتجنا ذلك مبكرًا.

البيانات الأساسية:

```text
id
username
email
password
is_staff
is_active
date_joined
```

---

## 5. UserProfile

## لماذا نحتاج UserProfile؟

Django User لا يحتوي role مخصص مثل customer/courier.

لذلك نضيف profile مرتبط بـ user.

### Fields

```text
id
user
role
phone
created_at
updated_at
```

### role values

```text
customer
courier
admin
locker_device
```

### Relationships

```text
UserProfile -> User
OneToOne
```

### Constraints

- كل user له profile واحد.
- role مطلوب.

### لماذا ليس Groups فقط؟

Django Groups ممتازة، لكن للمبتدئ والـ MVP وجود `role` واضح في profile أسهل للفهم والاختبار.

لاحقًا ممكن ندمج Groups/Permissions لو احتجنا صلاحيات أكثر تعقيدًا.

---

## 6. Product

يمثل المنتج الذي يطلبه العميل.

### Fields

```text
id
name
description
price
stock
size
is_active
created_at
updated_at
```

### size values

```text
small
medium
large
```

### Constraints

- `price` لا يجب أن يكون سالبًا.
- `stock` لا يجب أن يكون سالبًا.
- `name` مطلوب.
- `size` مطلوب.

### لماذا size مهم؟

لأن النظام يحتاج اختيار drawer مناسب لحجم الطلب.

---

## 7. LockerStation

يمثل ماكينة locker في مكان معين.

### Fields

```text
id
name
code
address
latitude
longitude
status
created_at
updated_at
```

### status values

```text
online
offline
maintenance
```

### Constraints

- `code` يجب أن يكون unique.
- `name` مطلوب.
- locker offline لا يجب أن يتم اقتراحه من AI.

### لماذا code؟

الماكينة تحتاج identifier ثابت مثل:

```text
LOCKER-001
```

---

## 8. Drawer

يمثل درج داخل locker station.

### Fields

```text
id
locker_station
number
size
status
current_order
created_at
updated_at
```

### size values

```text
small
medium
large
```

### status values

```text
available
reserved
occupied
out_of_service
```

### Relationships

```text
Drawer -> LockerStation
ManyToOne
```

```text
Drawer -> Order
OneToOne nullable for current_order
```

### Constraints

- لا يمكن تكرار `number` داخل نفس `locker_station`.
- drawer status `available` يعني لا يوجد current_order.
- drawer status `occupied` يعني يوجد current_order.

### لماذا current_order؟

حتى نعرف بسرعة أي order داخل الدرج حاليًا.

---

## 9. Order

يمثل طلب العميل.

### Fields

```text
id
customer
assigned_courier
selected_locker
assigned_drawer
status
payment_status
total_price
created_at
updated_at
```

### Relationships

```text
Order -> User as customer
ManyToOne
```

```text
Order -> User as assigned_courier
ManyToOne nullable
```

```text
Order -> LockerStation as selected_locker
ManyToOne nullable
```

```text
Order -> Drawer as assigned_drawer
OneToOne nullable
```

### status values

```text
Pending
Assigned_To_Courier
Ready_For_Deposit
Stored_In_Locker
Ready_For_Pickup
Picked_Up
Cancelled
Expired
Returned
```

### payment_status values

```text
unpaid
paid
refunded
```

في الـ MVP:

```text
payment_status مجرد simulation
```

### Constraints

- customer مطلوب.
- total_price لا يجب أن يكون سالبًا.
- assigned_drawer يكون null حتى يتم تخصيص درج.
- picked up order لا يجب أن يستخدم QR مرة أخرى.

---

## 10. OrderItem

يمثل المنتجات داخل الطلب.

### Fields

```text
id
order
product
quantity
unit_price
created_at
```

### Relationships

```text
OrderItem -> Order
ManyToOne
```

```text
OrderItem -> Product
ManyToOne
```

### Constraints

- quantity يجب أن يكون أكبر من 0.
- unit_price لا يجب أن يكون سالبًا.

### لماذا نخزن unit_price؟

لأن سعر المنتج قد يتغير لاحقًا، لكن order يجب أن يحتفظ بسعر وقت الشراء.

---

## 11. QRToken

يمثل token آمن يتم تحويله إلى QR.

### Fields

```text
id
order
user
token_hash
type
expires_at
used_at
created_at
```

### type values

```text
deposit
pickup
```

### Relationships

```text
QRToken -> Order
ManyToOne
```

```text
QRToken -> User
ManyToOne nullable
```

### Constraints

- token_hash يجب أن يكون unique.
- expires_at مطلوب.
- used_at يكون null قبل الاستخدام.
- token لا يستخدم أكثر من مرة.

### لماذا token_hash وليس token؟

للأمان.

نخزن hash للـ token في database بدل القيمة الأصلية. لو database اتسربت، لا يستطيع المهاجم استخدام tokens بسهولة.

### ماذا يحتوي QR؟

الـ QR يحتوي token عشوائي آمن.

لا يحتوي:

```text
drawer_id
order_id
user_id
```

بشكل مكشوف.

---

## 12. LockerEventLog

يمثل سجل الأحداث المهمة.

### Fields

```text
id
locker_station
drawer
order
actor
event_type
metadata
created_at
```

### event_type values

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
locker_heartbeat
```

### Relationships

```text
LockerEventLog -> LockerStation nullable
LockerEventLog -> Drawer nullable
LockerEventLog -> Order nullable
LockerEventLog -> User as actor nullable
```

### لماذا metadata؟

لتخزين معلومات إضافية بصيغة JSON، مثل:

```json
{
  "reason": "invalid token",
  "machine_id": "LOCKER-001"
}
```

---

## 13. AIRecommendationLog

يمثل سجل قرارات AI recommendation.

### Fields

```text
id
order
customer
request_payload
recommended_locker
score
reason
used_fallback
created_at
```

### Relationships

```text
AIRecommendationLog -> Order nullable
AIRecommendationLog -> User as customer
AIRecommendationLog -> LockerStation as recommended_locker nullable
```

### لماذا نحتاجه؟

- نراجع لماذا تم اختيار locker معين.
- نثبت أن AI feature تعمل.
- نستخدم البيانات لاحقًا لتطوير ML model.
- نساعد في debugging.

### used_fallback

قيمة boolean.

```text
True
```

إذا Django استخدم fallback بدل FastAPI AI service.

---

## 14. Status Transition Rules

لا يجب تغيير order status عشوائيًا.

الانتقالات المسموحة في الـ MVP:

```text
Pending -> Assigned_To_Courier
Assigned_To_Courier -> Ready_For_Deposit
Ready_For_Deposit -> Stored_In_Locker
Stored_In_Locker -> Ready_For_Pickup
Ready_For_Pickup -> Picked_Up
Ready_For_Pickup -> Expired
Expired -> Returned
Pending -> Cancelled
Assigned_To_Courier -> Cancelled
```

أي انتقال خارج هذه القائمة يحتاج مراجعة.

---

## 15. Drawer Status Rules

### available

معناه:

```text
drawer فارغ وجاهز
```

### reserved

معناه:

```text
drawer محجوز لطلب لكن الطلب لم يوضع بعد
```

### occupied

معناه:

```text
الطلب داخل الدرج
```

### out_of_service

معناه:

```text
الدرج غير صالح للاستخدام
```

---

## 16. Important Indexes

لتحسين الأداء لاحقًا، نحتاج indexes على:

```text
Order.customer
Order.assigned_courier
Order.status
Drawer.locker_station
Drawer.status
QRToken.token_hash
QRToken.expires_at
LockerEventLog.created_at
```

في Django، بعض العلاقات تضيف index تلقائيًا، لكن سنراجعها أثناء التنفيذ.

---

## 17. Data Ownership

في الـ MVP:

```text
Django owns the database.
```

FastAPI AI service لا يقرأ database مباشرة.

السبب:

- تقليل التعقيد.
- منع تضارب البيانات.
- جعل Django هو مصدر الحقيقة.

---

## 18. Security Notes

- لا نخزن QR token الأصلي.
- لا نضع drawer_id داخل QR.
- لا نسمح بفتح درج بدون QR validation.
- customer لا يرى orders غيره.
- courier لا يرى orders غير المخصصة له.
- emergency unlock يجب أن يسجل reason.

---

## 19. أسئلة مؤجلة

هذه الأسئلة لا تمنع تنفيذ الـ MVP:

- هل نستخدم custom user لاحقًا؟
- هل نستخدم PostGIS لحساب المسافات بدقة؟
- هل نضيف payment transactions table؟
- هل نحتاج table خاص بالnotifications؟
- هل نحتاج separate inventory transactions؟

سنؤجلها حتى يعمل الفلو الأساسي.

---

## 20. Definition of Done

تصميم قاعدة البيانات يعتبر جاهزًا عندما:

- كل model له مسؤولية واضحة.
- العلاقات بين الجداول واضحة.
- status values محددة.
- QR security واضحة.
- AIRecommendationLog محدد.
- constraints الأساسية مكتوبة.
- نقدر نبدأ Django models بناءً على هذا الملف.

