# Smart Delivery System - MVP Scope

## 1. الهدف من الـ MVP

الـ MVP هو أول نسخة عملية من المشروع.

هدفه ليس بناء كل شيء في المنتج النهائي، لكن إثبات أن الفكرة الأساسية تعمل من البداية للنهاية:

```text
Customer creates order
AI recommends locker
Courier deposits order
Customer picks up order using QR
Admin sees logs
```

إذا هذا الفلو اشتغل بشكل آمن وواضح، يبقى المشروع نجح كأول نسخة.

---

## 2. الفلو الأساسي المطلوب

أول نسخة يجب أن تثبت هذا السيناريو:

1. العميل يسجل دخول.
2. العميل يرى المنتجات.
3. العميل ينشئ order.
4. النظام يقترح أفضل locker باستخدام AI service.
5. الأدمن أو النظام يعيّن مندوب للطلب.
6. المندوب يرى الطلبات المخصصة له.
7. المندوب يحصل على deposit QR.
8. المندوب يمسح QR على الماكينة أو simulation.
9. الدرج الصحيح يفتح.
10. المندوب يضع الطلب داخل الدرج.
11. حالة الطلب تصبح `Ready_For_Pickup`.
12. العميل يحصل على pickup QR.
13. العميل يمسح QR على الماكينة أو simulation.
14. الدرج الصحيح يفتح.
15. حالة الطلب تصبح `Picked_Up`.
16. الأدمن يرى الأحداث في event logs.

---

## 3. داخل نطاق الـ MVP

هذه الأشياء يجب تنفيذها في أول نسخة.

### 3.1 Authentication

المطلوب:

- JWT login.
- Access token.
- Refresh token.
- حماية endpoints المهمة.

السبب:

لازم النظام يعرف من المستخدم قبل السماح له بإنشاء order أو رؤية بياناته.

---

### 3.2 User Roles

الأدوار المطلوبة:

```text
customer
courier
admin
locker_device
```

المطلوب:

- كل user يكون له role.
- كل role له صلاحيات مختلفة.

السبب:

العميل لا يجب أن يرى طلبات غيره، والمندوب لا يجب أن يرى كل الطلبات، والماكينة لا يجب أن تتصرف كأنها admin.

---

### 3.3 Products

المطلوب:

- عرض المنتجات.
- تفاصيل المنتج.
- إضافة وتعديل المنتجات من الأدمن.

الحقول الأساسية:

```text
name
description
price
stock
size
is_active
```

السبب:

المشروع فيه متجر بسيط، والعميل يحتاج يطلب منتج فعلي.

---

### 3.4 Orders

المطلوب:

- العميل ينشئ order.
- العميل يرى طلباته فقط.
- المندوب يرى الطلبات المخصصة له فقط.
- الأدمن يرى كل الطلبات.
- order status يتغير حسب المرحلة.

أهم statuses في الـ MVP:

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

السبب:

الـ order هو قلب النظام. كل شيء يدور حوله.

---

### 3.5 Locker Stations

المطلوب:

- إضافة locker station.
- تحديد location مبدئي.
- تحديد status:

```text
online
offline
maintenance
```

السبب:

النظام يحتاج يعرف أين توجد الماكينات المتاحة.

---

### 3.6 Drawers

المطلوب:

- كل locker يحتوي على drawers.
- كل drawer له رقم.
- كل drawer له size:

```text
small
medium
large
```

- كل drawer له status:

```text
available
reserved
occupied
out_of_service
```

السبب:

لازم نعرف أي درج فاضي، وأي درج مناسب لحجم الطلب.

---

### 3.7 AI Locker Recommendation

المطلوب:

- خدمة FastAPI منفصلة.
- endpoint يقترح أفضل locker.
- recommendation مبني على rule-based scoring في أول نسخة.

العوامل:

- قرب الـ locker.
- وجود درج مناسب.
- حالة الـ locker.
- نسبة الامتلاء.

السبب:

دي ميزة AI الأساسية في أول نسخة. تضيف قيمة حقيقية للمشروع وتخلي الاختيار أذكى من اختيار عشوائي.

ملاحظة:

لا نستخدم ML model في أول نسخة. نبدأ بقواعد واضحة قابلة للاختبار.

---

### 3.8 QR Tokens

المطلوب:

- deposit QR للمندوب.
- pickup QR للعميل.
- QR token يستخدم مرة واحدة فقط.
- QR token له expiration.
- QR لا يحتوي على drawer number بشكل مكشوف.

السبب:

الأمان في المشروع قائم بشكل كبير على QR. أي خطأ هنا ممكن يفتح درج غلط أو يعرّض طلبات العملاء للخطر.

---

### 3.9 Locker Scan API

المطلوب:

Endpoint تستدعيه الماكينة أو simulation عند scan QR:

```http
POST /api/locker/scan/
```

هذا endpoint يتحقق من:

- QR صحيح.
- QR لم يستخدم.
- QR لم ينته.
- order في status يسمح بالفتح.
- locker machine صحيحة.

السبب:

الماكينة لا يجب أن تفتح درج من نفسها. الـ backend هو صاحب القرار.

---

### 3.10 Event Logs

المطلوب:

تسجيل أحداث مهمة مثل:

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

السبب:

logs مهمة للأمان، debugging، والديمو أمام العميل أو لجنة المشروع.

---

### 3.11 Admin Dashboard

المطلوب:

باستخدام Django Admin في أول نسخة:

- إدارة المنتجات.
- إدارة الطلبات.
- إدارة lockers.
- إدارة drawers.
- رؤية QR tokens.
- رؤية event logs.
- emergency unlock كـ action أو endpoint لاحقًا.

السبب:

الأدمن يحتاج يشوف النظام ويديره بدون frontend خاص في البداية.

---

### 3.12 Tests

المطلوب:

اختبارات أساسية لـ:

- authentication.
- permissions.
- customer لا يرى orders غيره.
- courier لا يرى orders غيره.
- QR لا يستخدم مرتين.
- QR منتهي لا يعمل.
- AI recommendation تستبعد locker offline أو full.
- locker scan لا يفتح drawer مع QR غير صالح.

السبب:

المشروع هدفه يكون قوي في الـ CV وسوق العمل، والاختبارات جزء مهم من جودة السوفتوير.

---

### 3.13 Locker Simulation

المطلوب:

قبل الهاردوير الحقيقي، نعمل simulation بسيط:

- إدخال QR token.
- إرسال request إلى backend.
- عرض drawer opened أو error.

السبب:

simulation يخلينا نثبت الفلو حتى لو الهاردوير اتأخر.

---

## 4. خارج نطاق الـ MVP

هذه الأشياء مؤجلة ولا يتم تنفيذها في أول نسخة.

### 4.1 Payment Gateway

لن نربط بوابة دفع حقيقية في الـ MVP.

البديل:

```text
payment_status = paid / unpaid
```

كتجربة داخلية فقط.

---

### 4.2 AI Chatbot

لن نضيف chatbot في أول نسخة.

السبب:

الشات بوت ليس جزءًا أساسيًا من فتح الدرج واستلام الطلب.

---

### 4.3 Product Recommendation Engine

لن نضيف توصيات منتجات في أول نسخة.

السبب:

الـ AI الأهم للمشروع هو locker recommendation وليس product recommendation.

---

### 4.4 ML Model Training

لن ندرب model في أول نسخة.

السبب:

لا توجد بيانات حقيقية كافية في البداية. سنبدأ بـ rule-based scoring ثم نجمع data.

---

### 4.5 External Shipping Companies

لن ندعم شركات شحن خارجية في أول نسخة.

السبب:

هذا يحتاج integrations واتفاقات وصلاحيات إضافية.

---

### 4.6 Camera Proof Image

لن نستخدم كاميرا لإثبات الاستلام في أول نسخة.

البديل:

```text
Event logs
```

---

### 4.7 Offline Locker Mode

الماكينة تحتاج إنترنت في أول نسخة.

السبب:

التحقق من QR وفتح الدرج يجب أن يتم عن طريق backend لأسباب أمنية.

---

### 4.8 Multi-Vendor Marketplace

لن نجعل النظام marketplace متعدد البائعين في أول نسخة.

السبب:

نركز على شركة واحدة ومتجر واحد حتى يثبت الفلو الأساسي.

---

## 5. Assumptions

نفترض في أول نسخة:

- الشركة لديها مندوبين تابعين لها.
- كل order يتم وضعه في locker واحد.
- كل drawer يحتوي على order واحد فقط.
- العميل يملك تطبيق موبايل أو يمكن تمثيله من خلال API في البداية.
- الماكينة متصلة بالإنترنت.
- AI recommendation خدمة مساعدة وليست شرطًا وحيدًا لإكمال الطلب.

---

## 6. Constraints

قيود أول نسخة:

- لا يوجد payment حقيقي.
- لا يوجد frontend كامل في البداية.
- لا يوجد ML model.
- لا يوجد دعم offline.
- الهاردوير يمكن استبداله مؤقتًا بـ simulation.

---

## 7. Definition of Done للـ MVP

نعتبر الـ MVP ناجحًا عندما نستطيع تنفيذ هذا الديمو:

```text
1. Customer logs in.
2. Customer creates order.
3. AI service recommends locker.
4. Admin assigns courier.
5. Courier generates deposit QR.
6. Locker simulation scans deposit QR.
7. Correct drawer opens.
8. Courier stores order.
9. Customer receives pickup QR.
10. Locker simulation scans pickup QR.
11. Correct drawer opens.
12. Order becomes Picked_Up.
13. Admin sees event logs.
14. Tests pass.
```

