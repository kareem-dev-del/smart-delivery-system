from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from audit.models import AuditLog
from orders.models import Order

from .models import UserProfile


User = get_user_model()


class AccountAPIViewTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="customer",
            password="SafePass123!2026",
        )

    def register_url(self):
        return reverse("account-register")

    def me_url(self):
        return reverse("account-me")

    def test_customer_can_register_and_receive_tokens(self):
        response = self.client.post(
            self.register_url(),
            {
                "username": "kareem",
                "password": "SafePass123!2026",
                "password_confirm": "SafePass123!2026",
                "first_name": "Kareem",
                "email": "kareem@example.com",
                "phone": "+201012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertEqual(response.data["user"]["username"], "kareem")
        self.assertEqual(
            response.data["user"]["phone"],
            "+201012345678",
        )
        self.assertEqual(response["Cache-Control"], "no-store")

        user = User.objects.get(username="kareem")

        self.assertTrue(
            user.check_password("SafePass123!2026")
        )
        self.assertEqual(
            user.profile.role,
            UserProfile.Role.CUSTOMER,
        )

    def test_register_rejects_existing_username(self):
        response = self.client.post(
            self.register_url(),
            {
                "username": "Customer",
                "password": "SafePass123!2026",
                "password_confirm": "SafePass123!2026",
                "phone": "+201012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("username", response.data)

    def test_register_rejects_mismatched_password_confirmation(self):
        response = self.client.post(
            self.register_url(),
            {
                "username": "new-customer",
                "password": "SafePass123!2026",
                "password_confirm": "DifferentPass123!2026",
                "phone": "+201012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password_confirm", response.data)

    def test_unauthenticated_user_cannot_read_profile(self):
        response = self.client.get(self.me_url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_authenticated_user_can_read_own_profile(self):
        self.user.profile.phone = "+201111111111"
        self.user.profile.save(update_fields=("phone",))

        self.client.force_authenticate(user=self.user)

        response = self.client.get(self.me_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["username"], "customer")
        self.assertEqual(
            response.data["phone"],
            "+201111111111",
        )
        self.assertEqual(
            response.data["role"],
            UserProfile.Role.CUSTOMER,
        )

    def test_authenticated_user_can_update_own_profile(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.patch(
            self.me_url(),
            {
                "first_name": "Kareem",
                "phone": "01012345678",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["first_name"], "Kareem")
        self.assertEqual(
            response.data["phone"],
            "01012345678",
        )

        self.user.refresh_from_db()
        self.user.profile.refresh_from_db()

        self.assertEqual(self.user.first_name, "Kareem")
        self.assertEqual(
            self.user.profile.phone,
            "01012345678",
        )


class AdminCourierListAPIViewTests(APITestCase):
    def setUp(self):
        self.admin_user = User.objects.create_user(
            username="admin",
            password="SafePass123!2026",
        )
        self.admin_user.profile.role = UserProfile.Role.ADMIN
        self.admin_user.profile.save(update_fields=("role", "updated_at"))

        self.courier = User.objects.create_user(
            username="active-courier",
            password="SafePass123!2026",
        )
        self.courier.profile.role = UserProfile.Role.COURIER
        self.courier.profile.phone = "+201012345678"
        self.courier.profile.save(update_fields=("role", "phone", "updated_at"))

        self.inactive_courier = User.objects.create_user(
            username="inactive-courier",
            password="SafePass123!2026",
            is_active=False,
        )
        self.inactive_courier.profile.role = UserProfile.Role.COURIER
        self.inactive_courier.profile.save(update_fields=("role", "updated_at"))

    def url(self):
        return reverse("admin-courier-list")

    def test_admin_can_list_active_couriers(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(self.url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.data,
            [
                {
                    "id": self.courier.id,
                    "username": "active-courier",
                    "first_name": "",
                    "last_name": "",
                    "email": "",
                    "phone": "+201012345678",
                    "role": UserProfile.Role.COURIER,
                    "is_active": True,
                    "is_on_shift": False,
                    "shift_updated_at": None,
                    "active_order_count": 0,
                    "dispatch_status": "off_shift",
                }
            ],
        )

    def test_non_admin_cannot_list_couriers(self):
        self.client.force_authenticate(user=self.courier)

        response = self.client.get(self.url())

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_unauthenticated_user_cannot_list_couriers(self):
        response = self.client.get(self.url())

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class AdminManagedAccountAPIViewTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(username="ops-admin", password="SafePass123!2026")
        self.admin.profile.role = UserProfile.Role.ADMIN
        self.admin.profile.save(update_fields=("role", "updated_at"))
        self.customer = User.objects.create_user(username="managed-customer", password="SafePass123!2026")
        self.courier = User.objects.create_user(username="managed-courier", password="SafePass123!2026")
        self.courier.profile.role = UserProfile.Role.COURIER
        self.courier.profile.save(update_fields=("role", "updated_at"))

    def list_url(self):
        return reverse("admin-managed-user-list-create")

    def status_url(self, user):
        return reverse("admin-managed-user-status", args=(user.id,))

    def shift_url(self, user):
        return reverse("admin-courier-shift", args=(user.id,))

    def valid_payload(self, **overrides):
        payload = {
            "username": "new-courier",
            "password": "DistinctPass123!2026",
            "password_confirm": "DistinctPass123!2026",
            "first_name": "New",
            "last_name": "Courier",
            "email": "new-courier@example.com",
            "phone": "+201012345678",
            "role": UserProfile.Role.COURIER,
        }
        payload.update(overrides)
        return payload

    def test_admin_can_list_customer_courier_and_admin_accounts(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(self.list_url())

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual({item["role"] for item in response.data}, {"customer", "courier", "admin"})
        self.assertTrue(all("is_active" in item for item in response.data))

    def test_admin_can_create_customer_courier_or_admin_accounts(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.post(self.list_url(), self.valid_payload(), format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["role"], UserProfile.Role.COURIER)
        self.assertTrue(response.data["is_active"])
        created = User.objects.get(username="new-courier")
        self.assertTrue(created.check_password("DistinctPass123!2026"))
        self.assertEqual(AuditLog.objects.filter(action=AuditLog.Action.ACCOUNT_CREATED).count(), 1)

    def test_admin_can_create_an_admin_through_managed_accounts(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.post(
            self.list_url(),
            self.valid_payload(username="new-admin", role=UserProfile.Role.ADMIN),
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["role"], UserProfile.Role.ADMIN)
        self.assertTrue(User.objects.filter(username="new-admin", profile__role=UserProfile.Role.ADMIN).exists())

    def test_admin_cannot_deactivate_own_admin_account(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.patch(
            self.status_url(self.admin),
            {"is_active": False},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.admin.refresh_from_db()
        self.assertTrue(self.admin.is_active)

    def test_admin_can_deactivate_another_admin(self):
        other_admin = User.objects.create_user(
            username="another-admin",
            password="SafePass123!2026",
        )
        other_admin.profile.role = UserProfile.Role.ADMIN
        other_admin.profile.save(update_fields=("role", "updated_at"))
        self.client.force_authenticate(user=self.admin)

        response = self.client.patch(
            self.status_url(other_admin),
            {"is_active": False},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data["is_active"])

    def test_admin_can_deactivate_and_reactivate_accounts(self):
        self.client.force_authenticate(user=self.admin)

        deactivated = self.client.patch(
            self.status_url(self.courier),
            {"is_active": False},
            format="json",
        )
        self.assertEqual(deactivated.status_code, status.HTTP_200_OK)
        self.assertFalse(deactivated.data["is_active"])

        reactivated = self.client.patch(
            self.status_url(self.courier),
            {"is_active": True},
            format="json",
        )
        self.assertEqual(reactivated.status_code, status.HTTP_200_OK)
        self.assertTrue(reactivated.data["is_active"])
        self.assertEqual(AuditLog.objects.filter(action=AuditLog.Action.ACCOUNT_STATUS_CHANGED).count(), 2)

    def test_admin_can_start_and_end_courier_shift(self):
        self.client.force_authenticate(user=self.admin)

        started = self.client.patch(self.shift_url(self.courier), {"is_on_shift": True}, format="json")
        self.assertEqual(started.status_code, status.HTTP_200_OK)
        self.assertTrue(started.data["is_on_shift"])
        self.assertEqual(started.data["dispatch_status"], "available")
        self.assertIsNotNone(started.data["shift_updated_at"])

        ended = self.client.patch(self.shift_url(self.courier), {"is_on_shift": False}, format="json")
        self.assertEqual(ended.status_code, status.HTTP_200_OK)
        self.assertEqual(ended.data["dispatch_status"], "off_shift")
        self.assertEqual(AuditLog.objects.filter(action=AuditLog.Action.COURIER_SHIFT_CHANGED).count(), 2)

    def test_cannot_end_shift_while_courier_has_active_orders(self):
        self.courier.profile.is_on_shift = True
        self.courier.profile.save(update_fields=("is_on_shift",))
        Order.objects.create(
            customer=self.customer,
            status=Order.Status.ASSIGNED,
            assigned_courier=self.courier,
        )
        self.client.force_authenticate(user=self.admin)

        response = self.client.patch(self.shift_url(self.courier), {"is_on_shift": False}, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.courier.profile.refresh_from_db()
        self.assertTrue(self.courier.profile.is_on_shift)

    def test_cannot_start_shift_for_inactive_courier(self):
        self.courier.is_active = False
        self.courier.save(update_fields=("is_active",))
        self.client.force_authenticate(user=self.admin)

        response = self.client.patch(self.shift_url(self.courier), {"is_on_shift": True}, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_non_admin_cannot_manage_accounts(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(self.list_url())

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class CourierSelfShiftAPIViewTests(APITestCase):
    def setUp(self):
        self.courier = User.objects.create_user(
            username="self-shift-courier",
            password="SafePass123!2026",
        )
        self.courier.profile.role = UserProfile.Role.COURIER
        self.courier.profile.save(update_fields=("role", "updated_at"))
        self.customer = User.objects.create_user(
            username="self-shift-customer",
            password="SafePass123!2026",
        )

    def url(self):
        return reverse("courier-self-shift")

    def test_courier_can_read_and_update_own_shift(self):
        self.client.force_authenticate(user=self.courier)
        current = self.client.get(self.url())
        self.assertEqual(current.status_code, status.HTTP_200_OK)
        self.assertFalse(current.data["is_on_shift"])

        updated = self.client.patch(self.url(), {"is_on_shift": True}, format="json")
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertTrue(updated.data["is_on_shift"])
        self.assertEqual(updated.data["dispatch_status"], "available")
        self.assertEqual(
            AuditLog.objects.filter(
                action=AuditLog.Action.COURIER_SHIFT_CHANGED,
                actor=self.courier,
            ).count(),
            1,
        )

    def test_customer_cannot_change_a_courier_shift(self):
        self.client.force_authenticate(user=self.customer)
        response = self.client.patch(self.url(), {"is_on_shift": True}, format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_courier_cannot_end_shift_with_an_active_order(self):
        self.courier.profile.is_on_shift = True
        self.courier.profile.save(update_fields=("is_on_shift",))
        Order.objects.create(
            customer=self.customer,
            assigned_courier=self.courier,
            status=Order.Status.ASSIGNED,
        )
        self.client.force_authenticate(user=self.courier)
        response = self.client.patch(self.url(), {"is_on_shift": False}, format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.courier.profile.refresh_from_db()
        self.assertTrue(self.courier.profile.is_on_shift)
