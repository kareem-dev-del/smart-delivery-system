from rest_framework import serializers

from .models import Drawer, LockerDevice, LockerStation
from .services import get_locker_device_connection_status


class DrawerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Drawer
        fields = (
            "id",
            "number",
            "size",
            "status",
        )

class DrawerCreateSerializer(serializers.Serializer):
    number = serializers.IntegerField(min_value=1)
    size = serializers.ChoiceField(
        choices=Drawer.Size.choices,
    )


class DrawerMaintenanceStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=(
            Drawer.Status.AVAILABLE,
            Drawer.Status.OUT_OF_SERVICE,
        )
    )

class LockerDeviceProvisionSerializer(serializers.Serializer):
    device_code = serializers.CharField(max_length=100)

    def validate_device_code(self, value):
        normalized_code = value.strip().upper()

        if not normalized_code:
            raise serializers.ValidationError(
                "Device code cannot be empty."
            )

        if not all(
            character.isalnum() or character == "-"
            for character in normalized_code
        ):
            raise serializers.ValidationError(
                "Device code may contain only letters, numbers, and hyphens."
            )

        return normalized_code


class LockerDeviceProvisionResponseSerializer(serializers.Serializer):
    device_id = serializers.IntegerField(read_only=True)
    locker_station_id = serializers.IntegerField(read_only=True)
    locker_code = serializers.CharField(read_only=True)
    device_code = serializers.CharField(read_only=True)
    username = serializers.CharField(read_only=True)
    initial_password = serializers.CharField(read_only=True)




class LockerStationListSerializer(serializers.ModelSerializer):
    available_drawers_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = LockerStation
        fields = (
            "id",
            "name",
            "code",
            "address",
            "latitude",
            "longitude",
            "status",
            "available_drawers_count",
        )


class LockerStationDetailSerializer(serializers.ModelSerializer):
    drawers = DrawerSerializer(many=True, read_only=True)

    class Meta:
        model = LockerStation
        fields = (
            "id",
            "name",
            "code",
            "address",
            "latitude",
            "longitude",
            "status",
            "drawers",
        )
class AdminLockerStationWriteSerializer(serializers.ModelSerializer):
    code = serializers.CharField(max_length=50)

    class Meta:
        model = LockerStation
        fields = (
            "id",
            "name",
            "code",
            "address",
            "latitude",
            "longitude",
            "status",
        )
        read_only_fields = ("id",)

    def validate_code(self, value):
        normalized_code = value.strip().upper()

        if not normalized_code:
            raise serializers.ValidationError(
                "Locker code cannot be empty."
            )

        if not all(
            character.isalnum() or character == "-"
            for character in normalized_code
        ):
            raise serializers.ValidationError(
                "Locker code may contain only letters, numbers, and hyphens."
            )

        lockers = LockerStation.objects.filter(code=normalized_code)

        if self.instance:
            lockers = lockers.exclude(pk=self.instance.pk)

        if lockers.exists():
            raise serializers.ValidationError(
                "A locker station with this code already exists."
            )

        return normalized_code

    def validate_latitude(self, value):
        if value < -90 or value > 90:
            raise serializers.ValidationError(
                "Latitude must be between -90 and 90."
            )

        return value

    def validate_longitude(self, value):
        if value < -180 or value > 180:
            raise serializers.ValidationError(
                "Longitude must be between -180 and 180."
            )

        return value




class PickupQRScanSerializer(serializers.Serializer):
    token = serializers.CharField(
        min_length=20,
        max_length=512,
        trim_whitespace=True,
    )


class OpenDrawerAuthorizationSerializer(serializers.Serializer):
    command = serializers.CharField(read_only=True)
    drawer_number = serializers.IntegerField(read_only=True)
    order_public_id = serializers.UUIDField(read_only=True)   


class CollectionConfirmationResponseSerializer(serializers.Serializer):
    order_public_id = serializers.UUIDField(read_only=True)
    status = serializers.CharField(read_only=True)
    drawer_number = serializers.IntegerField(read_only=True)
    drawer_status = serializers.CharField(read_only=True)
    collected_at = serializers.DateTimeField(read_only=True)

class ReturnConfirmationResponseSerializer(serializers.Serializer):
    order_public_id = serializers.UUIDField(read_only=True)
    status = serializers.CharField(read_only=True)
    drawer_number = serializers.IntegerField(read_only=True)
    drawer_status = serializers.CharField(read_only=True)
    returned_at = serializers.DateTimeField(read_only=True)    


class LockerDeviceHeartbeatResponseSerializer(serializers.Serializer):
    device_code = serializers.CharField(read_only=True)
    locker_code = serializers.CharField(read_only=True)
    locker_status = serializers.CharField(read_only=True)
    last_heartbeat_at = serializers.DateTimeField(read_only=True)    



class AdminLockerDeviceSerializer(serializers.ModelSerializer):
    locker_station_id = serializers.IntegerField(read_only=True)
    locker_name = serializers.CharField(
        source="locker_station.name",
        read_only=True,
    )
    locker_code = serializers.CharField(
        source="locker_station.code",
        read_only=True,
    )
    locker_station_status = serializers.CharField(
        source="locker_station.status",
        read_only=True,
    )
    connection_status = serializers.SerializerMethodField()

    class Meta:
        model = LockerDevice
        fields = (
            "id",
            "locker_station_id",
            "locker_name",
            "locker_code",
            "locker_station_status",
            "device_code",
            "is_active",
            "last_heartbeat_at",
            "connection_status",
            "created_at",
            "updated_at",
        )

    def get_connection_status(self, locker_device):
        return get_locker_device_connection_status(
            locker_device=locker_device,
            now=self.context.get("now"),
        )   

class AdminDashboardSummarySerializer(serializers.Serializer):
    generated_at = serializers.DateTimeField(read_only=True)

    orders_by_status = serializers.DictField(
        child=serializers.IntegerField(min_value=0),
        read_only=True,
    )
    locker_stations_by_status = serializers.DictField(
        child=serializers.IntegerField(min_value=0),
        read_only=True,
    )
    drawers_by_status = serializers.DictField(
        child=serializers.IntegerField(min_value=0),
        read_only=True,
    )
    devices_by_connection_status = serializers.DictField(
        child=serializers.IntegerField(min_value=0),
        read_only=True,
    )      


class LockerDeviceActivationSerializer(serializers.Serializer):
    is_active = serializers.BooleanField()     