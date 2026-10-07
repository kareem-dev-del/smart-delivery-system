from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import UserProfile
from .models import Product


from django.core.cache import cache

from .cache import ACTIVE_PRODUCT_LIST_CACHE_KEY

User = get_user_model()


class ProductAPITests(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username="customer",
            password="testpass123",
        )
        self.admin_user = User.objects.create_user(
            username="admin",
            password="testpass123",
            is_staff=True,
        )

        self.customer.profile.role = UserProfile.Role.CUSTOMER
        self.customer.profile.save()

        self.admin_user.profile.role = UserProfile.Role.ADMIN
        self.admin_user.profile.save()

        self.active_product = Product.objects.create(
            name="Active Watch",
            description="Visible product",
            price="2500.00",
            stock=10,
            size=Product.Size.SMALL,
            is_active=True,
        )
        self.inactive_product = Product.objects.create(
            name="Inactive Watch",
            description="Hidden product",
            price="3000.00",
            stock=5,
            size=Product.Size.SMALL,
            is_active=False,
        )


        cache.delete(ACTIVE_PRODUCT_LIST_CACHE_KEY)
        self.addCleanup(
            cache.delete,
            ACTIVE_PRODUCT_LIST_CACHE_KEY,
        )
    def test_active_product_list_is_cached(self):
        response = self.client.get(
            reverse("product-list-create")
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            cache.get(ACTIVE_PRODUCT_LIST_CACHE_KEY),
            response.data,
        )

    def test_product_save_invalidates_cached_list(self):
        self.client.get(reverse("product-list-create"))

        self.assertIsNotNone(
            cache.get(ACTIVE_PRODUCT_LIST_CACHE_KEY)
        )

        with self.captureOnCommitCallbacks(execute=True):
            self.active_product.stock = 7
            self.active_product.save(
                update_fields=("stock", "updated_at")
            )

        self.assertIsNone(
            cache.get(ACTIVE_PRODUCT_LIST_CACHE_KEY)
        )

        response = self.client.get(
            reverse("product-list-create")
        )
        active_product = next(
            product
            for product in response.data
            if product["id"] == self.active_product.id
        )

        self.assertEqual(active_product["stock"], 7)              

    def test_anyone_can_list_active_products(self):
        response = self.client.get(reverse("product-list-create"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        product_names = [product["name"] for product in response.data]
        self.assertIn("Active Watch", product_names)
        self.assertNotIn("Inactive Watch", product_names)

    def test_customer_cannot_create_product(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            reverse("product-list-create"),
            {
                "name": "New Watch",
                "description": "Customer should not create this",
                "price": "1000.00",
                "stock": 3,
                "size": Product.Size.SMALL,
                "is_active": True,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_create_product(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.post(
            reverse("product-list-create"),
            {
                "name": "Admin Watch",
                "description": "Created by admin",
                "price": "1500.00",
                "stock": 7,
                "size": Product.Size.MEDIUM,
                "is_active": True,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(Product.objects.filter(name="Admin Watch").exists())

    def test_anyone_can_retrieve_active_product(self):
        response = self.client.get(
            reverse("product-detail", kwargs={"pk": self.active_product.pk})
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], "Active Watch")

    def test_anonymous_user_cannot_retrieve_inactive_product(self):
        response = self.client.get(
            reverse("product-detail", kwargs={"pk": self.inactive_product.pk})
        )

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_admin_can_retrieve_inactive_product(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(
            reverse("product-detail", kwargs={"pk": self.inactive_product.pk})
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], "Inactive Watch")


    def test_customer_cannot_update_product(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.patch(
            reverse("product-detail", kwargs={"pk": self.active_product.pk}),
            {
                "price": "9999.00",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.active_product.refresh_from_db()
        self.assertEqual(str(self.active_product.price), "2500.00")        



    def test_admin_can_update_product(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.patch(
            reverse("product-detail", kwargs={"pk": self.active_product.pk}),
            {
                "price": "1999.00",
                "stock": 20,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.active_product.refresh_from_db()
        self.assertEqual(str(self.active_product.price), "1999.00")
        self.assertEqual(self.active_product.stock, 20)


    def test_customer_cannot_replace_product(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.put(
            reverse("product-detail", kwargs={"pk": self.active_product.pk}),
            {
                "name": "Changed Watch",
                "description": "Should not change",
                "price": "9999.00",
                "stock": 100,
                "size": Product.Size.LARGE,
                "is_active": False,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.active_product.refresh_from_db()
        self.assertEqual(self.active_product.name, "Active Watch")
        self.assertTrue(self.active_product.is_active)