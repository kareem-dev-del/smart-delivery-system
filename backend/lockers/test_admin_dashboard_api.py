from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from orders.models import Order

from notifications.models import Notification

from .models import Drawer, LockerDevice, LockerStation


User = get_user_model()


@override_settings(LOCKER_DEVICE_HEARTBEAT_TIMEOUT_SECONDS=60)
class AdminDashboardSummaryAPIViewTests(APITestCase):
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
        self.customer.profile.role = UserProfile.Role.CUSTOMER
        self.customer.profile.save(update_fields=("role",))

        self.online_locker = self.create_locker_device(
            code="NASR-001",
            last_heartbeat_at=timezone.now(),
        )
        self.create_locker_device(
            code="MAADI-001",
            last_heartbeat_at=timezone.now() - timedelta(seconds=61),
        )
        self.create_locker_device(code="ZAYED-001")
        self.create_locker_device(
            code="HELIO-001",
            is_active=False,
            last_heartbeat_at=timezone.now(),
        )

        Drawer.objects.create(
            locker_station=self.online_locker,
            number=1,
            size=Drawer.Size.SMALL,
            status=Drawer.Status.AVAILABLE,
        )
        Drawer.objects.create(
            locker_station=self.online_locker,
            number=2,
            size=Drawer.Size.MEDIUM,
            status=Drawer.Status.OCCUPIED,
        )

        Order.objects.create(
            customer=self.customer,
            status=Order.Status.AWAITING_LOCKER,
        )
        Order.objects.create(
            customer=self.customer,
            locker_station=self.online_locker,
            status=Order.Status.READY_FOR_PICKUP,
        )
        Order.objects.create(
            customer=self.customer,
            status=Order.Status.EXPIRED,
        )

        Notification.objects.create(
            user=self.customer,
            notification_type=Notification.Type.ORDER_READY_FOR_PICKUP,
            title="Ready",
            message="Order is ready.",
        )
        Notification.objects.create(
            user=self.customer,
            notification_type=Notification.Type.ORDER_PICKUP_EXPIRED,
            title="Failed notification",
            message="Email failed.",
            delivery_status=Notification.DeliveryStatus.FAILED,
            delivery_error="SMTP error",
        )



    def create_locker_device(
        self,
        *,
        code,
        is_active=True,
        last_heartbeat_at=None,
    ):
        locker = LockerStation.objects.create(
            name=f"{code} Locker",
            code=code,
            address="Cairo, Egypt",
            latitude="30.000000",
            longitude="31.000000",
            status=LockerStation.Status.ONLINE,
        )

        device_user = User.objects.create_user(
            username=f"{code.lower()}-device",
            password="test-password",
        )
        device_user.profile.role = UserProfile.Role.LOCKER_DEVICE
        device_user.profile.save(update_fields=("role",))

        LockerDevice.objects.create(
            locker_station=locker,
            user=device_user,
            device_code=f"{code}-CONTROLLER",
            is_active=is_active,
            last_heartbeat_at=last_heartbeat_at,
        )

        return locker

    def test_non_admin_cannot_access_dashboard(self):
        response = self.client.get(
            reverse("admin-dashboard-summary")
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

        self.client.force_authenticate(user=self.customer)

        response = self.client.get(
            reverse("admin-dashboard-summary")
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_admin_receives_operational_summary(self):
        self.client.force_authenticate(user=self.admin)

        response = self.client.get(
            reverse("admin-dashboard-summary")
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.assertEqual(response.data["totals"]["orders"], 3)
        self.assertEqual(response.data["totals"]["locker_stations"], 4)
        self.assertEqual(response.data["totals"]["drawers"], 2)
        self.assertEqual(response.data["totals"]["locker_devices"], 4)
        self.assertEqual(response.data["totals"]["notifications"], 2)


        self.assertEqual(
            response.data["orders_by_status"][
                Order.Status.AWAITING_LOCKER
            ],
            1,
        )
        self.assertEqual(
            response.data["orders_by_status"][
                Order.Status.READY_FOR_PICKUP
            ],
            1,
        )

        self.assertEqual(
            response.data["orders_by_status"][Order.Status.EXPIRED],
            1,
        )

        self.assertEqual(
            response.data["drawers_by_status"][
                Drawer.Status.AVAILABLE
            ],
            1,
        )
        self.assertEqual(
            response.data["drawers_by_status"][
                Drawer.Status.OCCUPIED
            ],
            1,
        )
        self.assertEqual(
            response.data["devices_by_connection_status"][
                LockerDevice.ConnectionStatus.ONLINE
            ],
            1,
        )
        self.assertEqual(
            response.data["devices_by_connection_status"][
                LockerDevice.ConnectionStatus.STALE
            ],
            1,
        )
        self.assertEqual(
            response.data["devices_by_connection_status"][
                LockerDevice.ConnectionStatus.NEVER_CONNECTED
            ],
            1,
        )
        self.assertEqual(
            response.data["devices_by_connection_status"][
                LockerDevice.ConnectionStatus.INACTIVE
            ],
            1,
        )

        self.assertEqual(
            response.data["notifications_by_delivery_status"][
                Notification.DeliveryStatus.PENDING
            ],
            1,
        )
        self.assertEqual(
            response.data["notifications_by_delivery_status"][
                Notification.DeliveryStatus.FAILED
            ],
            1,
        )
        self.assertEqual(
            response.data["action_required"]["awaiting_locker_orders"],
            1,
        )
        self.assertEqual(
            response.data["action_required"]["expired_orders"],
            1,
        )
        self.assertEqual(
            response.data["action_required"]["failed_notifications"],
            1,
        )
        self.assertEqual(
            response.data["action_required"]["pending_notifications"],
            1,
        )
        self.assertEqual(
            response.data["action_required"]["unhealthy_devices"],
            3,
        )
