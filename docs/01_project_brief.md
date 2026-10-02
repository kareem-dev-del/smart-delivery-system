# Smart Delivery System - Project Brief

## 1. Project Name

```text
Smart Delivery System
```

اسم أوضح عند العرض:

```text
Smart Delivery Locker System
```

---

## 2. فكرة المشروع

المشروع عبارة عن نظام خزائن ذكية لاستلام الطلبات.

بدل ما المندوب يوصل الطلب للبيت ويبدأ يحصل تأخير أو مكالمات بسبب إن العميل مش موجود، المندوب يضع الطلب داخل درج آمن في ماكينة تشبه الـ ATM.

بعد وضع الطلب في الدرج، العميل يستلم QR Code على تطبيق الموبايل. عندما يذهب العميل للماكينة ويمسح الـ QR، يفتح الدرج الخاص بطلبه فقط، ويستلم الطلب في الوقت المناسب له.

---

## 3. المشكلة التي يحلها المشروع

في التوصيل التقليدي، آخر مرحلة في توصيل الطلب للعميل تكون غالبًا أصعب مرحلة.

أمثلة على المشكلة:

- المندوب يصل والعميل غير موجود في البيت.
- العميل يظل يتابع مع المندوب لمعرفة مكانه.
- المندوب يضيع وقتًا في الاتصالات ومحاولات التسليم.
- الطلب يتأخر بسبب عدم تنسيق الوقت بين العميل والمندوب.
- العميل يضطر للانتظار في البيت لاستلام الطلب.
- شركة الشحن تخسر وقتًا ومجهودًا في محاولات توصيل فاشلة.
- الطلب قد يتم تأجيله أو إرجاعه للشركة.

هذه المشكلة معروفة في مجال الشحن باسم:

```text
Last-Mile Delivery Problem
```

وهي مشكلة آخر مرحلة في التوصيل، عندما تنتقل الشحنة من المندوب إلى العميل النهائي.

---

## 4. الحل المقترح

الحل هو توفير ماكينة Smart Locker تحتوي على أدراج آمنة ومقفولة إلكترونيًا.

الفكرة الأساسية:

1. العميل يطلب order من تطبيق الموبايل.
2. النظام يقترح أفضل locker مناسب للعميل.
3. المندوب يضع الطلب داخل درج آمن في الماكينة.
4. العميل يحصل على QR Code.
5. العميل يذهب للماكينة في أي وقت مناسب.
6. العميل يمسح الـ QR.
7. الدرج الخاص بطلبه فقط يفتح.
8. النظام يسجل عملية الاستلام.

---

## 5. المستخدمون الأساسيون

### Customer

العميل الذي يطلب المنتج ويستلم الطلب من الماكينة.

### Courier

المندوب الذي يأخذ الطلب من الشركة ويضعه داخل الدرج المناسب.

### Admin

مسؤول الشركة الذي يدير المنتجات والطلبات والماكينات والأدراج ويتابع السجلات.

### Locker Machine

الماكينة التي تقرأ QR Code وتتواصل مع الـ Backend لفتح الدرج الصحيح.

---

## 6. مكونات النظام

النظام يتكون من:

- Mobile App للعميل والمندوب.
- Django REST API كـ Core Backend.
- FastAPI AI Microservice لاقتراح أفضل locker.
- PostgreSQL database.
- Admin Dashboard.
- Smart Locker Machine أو simulation في البداية.
- QR Code security.
- Event logs لكل عملية مهمة.

---

## 7. قيمة المشروع

المشروع يفيد العميل لأنه:

- يستلم الطلب في الوقت المناسب له.
- لا يحتاج للانتظار في البيت.
- يقلل المكالمات مع المندوب.
- يعطي تجربة استلام أسرع وأسهل.

المشروع يفيد الشركة لأنه:

- يقلل محاولات التوصيل الفاشلة.
- يقلل وقت المندوب.
- يحسن كفاءة التشغيل.
- يوفر تتبع واضح للطلبات.
- يسجل كل عمليات فتح الأدراج والاستلام.

---

## 8. AI في المشروع

الـ AI في النسخة الأولى لن يكون model معقد.

سنبدأ بميزة عملية اسمها:

```text
Smart Locker Recommendation
```

يعني النظام يقترح أفضل locker للعميل بناء على:

- قرب الـ locker من العميل.
- وجود درج متاح.
- حجم الطلب.
- حالة الماكينة.
- نسبة الامتلاء.

سيتم تنفيذ هذه الميزة كـ FastAPI microservice منفصل عن Django backend.

---

## 9. أول نسخة MVP

أول نسخة من المشروع يجب أن تثبت الفلو الأساسي:

```text
Customer Order -> AI Locker Recommendation -> Courier Deposit -> Customer Pickup
```

الـ MVP يحتوي على:

- JWT authentication.
- أدوار المستخدمين: customer, courier, admin, locker_device.
- Products API.
- Orders API.
- Lockers and Drawers.
- AI locker recommendation.
- QR tokens للإيداع والاستلام.
- Locker scan API.
- Admin dashboard.
- Event logs.
- Tests للأمان والصلاحيات.

---

## 10. خارج أول نسخة

هذه الأشياء مؤجلة ولا تدخل في أول نسخة:

- Payment gateway حقيقي.
- AI chatbot.
- Product recommendation engine.
- ML model training.
- شركات شحن خارجية.
- Camera proof image.
- Offline locker mode.
- Multi-vendor marketplace.

---

## 11. English Pitch

```text
Smart Delivery System is a smart locker-based pickup solution for e-commerce orders.
It solves the failed delivery problem by allowing couriers to deposit orders inside secure locker drawers, while customers can pick up their orders at any suitable time using a secure QR code.

The system includes a mobile application, Django REST backend, FastAPI AI recommendation service, admin dashboard, and a smart locker prototype or simulation.
```

---

## 12. Success Definition

The first successful version should demonstrate this complete flow:

```text
1. Customer logs in.
2. Customer creates an order.
3. AI service recommends the best locker.
4. Courier deposits the order in the locker.
5. Customer receives a pickup QR.
6. Customer scans the QR at the locker.
7. The correct drawer opens.
8. The order status becomes Picked_Up.
9. Admin can see all important event logs.
```

