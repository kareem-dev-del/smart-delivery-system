from io import BytesIO
import tempfile

from django.contrib.auth import get_user_model
from django.core.files.storage import default_storage
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase
from PIL import Image

from accounts.models import UserProfile
from .models import Category, Product


from django.core.cache import cache

from .cache import ACTIVE_PRODUCT_LIST_CACHE_KEY

User = get_user_model()


class ProductAPITests(APITestCase):
    def setUp(self):
        media_root = tempfile.TemporaryDirectory()
        self.addCleanup(media_root.cleanup)
        media_settings = override_settings(MEDIA_ROOT=media_root.name)
        media_settings.enable()
        self.addCleanup(media_settings.disable)

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
        active_product = next(
            product for product in response.data
            if product["id"] == self.active_product.id
        )
        self.assertIsNone(active_product["category_name"])

    def test_admin_can_list_active_and_inactive_products(self):
        self.client.force_authenticate(user=self.admin_user)

        response = self.client.get(reverse("admin-product-list"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        product_names = [product["name"] for product in response.data]
        self.assertIn("Active Watch", product_names)
        self.assertIn("Inactive Watch", product_names)

    def test_customer_cannot_list_admin_product_catalogue(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.get(reverse("admin-product-list"))

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_public_category_list_contains_only_active_categories(self):
        active = Category.objects.create(name="Electronics")
        Category.objects.create(name="Hidden", is_active=False)

        response = self.client.get(reverse("category-list"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([item["id"] for item in response.data], [active.id])

    def test_admin_can_create_and_update_categories(self):
        self.client.force_authenticate(user=self.admin_user)

        created = self.client.post(
            reverse("admin-category-list-create"),
            {"name": "  Home goods  ", "description": "Useful items"},
            format="json",
        )

        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        self.assertEqual(created.data["name"], "Home goods")
        updated = self.client.patch(
            reverse("admin-category-detail", args=[created.data["id"]]),
            {"is_active": False},
            format="json",
        )
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertFalse(updated.data["is_active"])

    def test_customer_cannot_manage_categories(self):
        self.client.force_authenticate(user=self.customer)

        response = self.client.post(
            reverse("admin-category-list-create"),
            {"name": "Restricted"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_assign_category_to_product(self):
        self.client.force_authenticate(user=self.admin_user)
        category = Category.objects.create(name="Accessories")

        response = self.client.patch(
            reverse("product-detail", args=[self.active_product.id]),
            {"category_id": category.id},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["category_name"], category.name)

    def test_category_update_invalidates_active_product_cache(self):
        category = Category.objects.create(name="Accessories")
        self.active_product.category = category
        self.active_product.save()
        self.client.get(reverse("product-list-create"))
        self.assertIsNotNone(cache.get(ACTIVE_PRODUCT_LIST_CACHE_KEY))

        with self.captureOnCommitCallbacks(execute=True):
            category.name = "Travel"
            category.save()

        self.assertIsNone(cache.get(ACTIVE_PRODUCT_LIST_CACHE_KEY))

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

    def test_admin_can_upload_product_image(self):
        self.client.force_authenticate(user=self.admin_user)
        image_content = BytesIO()
        Image.new("RGB", (2, 2), color="blue").save(image_content, format="PNG")
        image = SimpleUploadedFile(
            "admin-watch.png",
            image_content.getvalue(),
            content_type="image/png",
        )

        response = self.client.post(
            reverse("product-list-create"),
            {
                "name": "Watch with image",
                "price": "1500.00",
                "stock": 2,
                "size": Product.Size.SMALL,
                "image": image,
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        product = Product.objects.get(name="Watch with image")
        self.assertTrue(default_storage.exists(product.image.name))
        self.assertIn("/media/products/", response.data["image"])

    def test_product_image_rejects_non_image_upload(self):
        self.client.force_authenticate(user=self.admin_user)
        upload = SimpleUploadedFile(
            "not-an-image.png",
            b"not an image",
            content_type="image/png",
        )

        response = self.client.post(
            reverse("product-list-create"),
            {
                "name": "Invalid image product",
                "price": "10.00",
                "stock": 1,
                "image": upload,
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(Product.objects.filter(name="Invalid image product").exists())

    def test_admin_can_remove_existing_product_image(self):
        self.client.force_authenticate(user=self.admin_user)
        image_content = BytesIO()
        Image.new("RGB", (2, 2), color="blue").save(image_content, format="PNG")
        self.active_product.image.save(
            "watch.png",
            SimpleUploadedFile("watch.png", image_content.getvalue()),
        )
        image_name = self.active_product.image.name

        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.patch(
                reverse("product-detail", args=[self.active_product.id]),
                {"clear_image": "true"},
                format="multipart",
            )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.active_product.refresh_from_db()
        self.assertFalse(self.active_product.image)
        self.assertFalse(default_storage.exists(image_name))

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
