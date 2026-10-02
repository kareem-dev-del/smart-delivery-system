from rest_framework.throttling import AnonRateThrottle, UserRateThrottle


class AuthenticationRateThrottle(AnonRateThrottle):
    scope = "authentication"


class PasswordChangeRateThrottle(UserRateThrottle):
    scope = "password_change"


class LockerQRScanRateThrottle(UserRateThrottle):
    scope = "locker_qr_scan"