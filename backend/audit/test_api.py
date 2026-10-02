from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile

from .models import AuditLog


User = get_user_model()


class AuditLogAPIViewTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            username="admin",
            password="test-password",
            is_staff=True,
        )
        self.admin.profile.role = UserProfile.Role.ADMIN
        self.admin.profile.save(update_fields=("role",))

        self.customer = User.objects.create_user(
            username="customer",
            password="test-password",
        )

        AuditLog.objects.create(
            actor=self.admin,
            action=AuditLog.Action.DRAWER_CREATED,
            target_type=AuditLog.TargetType.DRAWER,
            target_id="10",
        )
        AuditLog.objects.create(
            actor=self.customer,
            action=AuditLog.Action.ORDER_CANCELLED,
            target_type=AuditLog.TargetType.ORDER,
            target_id="order-public-id",
        )

    def test_non_admin_cannot_access_audit_logs(self):
        response = self.client.get(reverse("audit-log-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.get(reverse("audit-log-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_admin_can_filter_audit_logs(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("audit-log-list"),
            {
                "action": AuditLog.Action.DRAWER_CREATED,
                "target_type": AuditLog.TargetType.DRAWER,
            },
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(
            response.data["results"][0]["target_id"],
            "10",
        )
        self.assertEqual(
            response.data["results"][0]["actor_username"],
            "admin",
        )