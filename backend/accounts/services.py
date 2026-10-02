from django.core.exceptions import ValidationError
from django.db import transaction
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.token_blacklist.models import (
    BlacklistedToken,
    OutstandingToken,
)
from rest_framework_simplejwt.tokens import RefreshToken


@transaction.atomic
def change_password_and_issue_tokens(*, user, new_password):
    user.set_password(new_password)
    user.save(update_fields=("password",))

    outstanding_tokens = (
        OutstandingToken.objects.select_for_update()
        .filter(user=user)
    )

    for outstanding_token in outstanding_tokens:
        BlacklistedToken.objects.get_or_create(
            token=outstanding_token
        )

    refresh = RefreshToken.for_user(user)

    return user, refresh


@transaction.atomic
def blacklist_refresh_token(*, user, raw_refresh_token):
    try:
        refresh = RefreshToken(raw_refresh_token)
    except TokenError as error:
        raise ValidationError(
            {"refresh": "Invalid or expired refresh token."}
        ) from error

    token_user_id = refresh.payload.get(
        api_settings.USER_ID_CLAIM
    )

    if str(token_user_id) != str(user.pk):
        raise ValidationError(
            {"refresh": "Refresh token does not belong to this user."}
        )

    refresh.blacklist()