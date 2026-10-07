from django.db import DatabaseError, connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET


def json_status(payload, status):
    response = JsonResponse(payload, status=status)
    response["Cache-Control"] = "no-store"
    return response


def database_is_available():
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except DatabaseError:
        return False

    return True


@require_GET
def health(request):
    return json_status(
        {
            "status": "ok",
        },
        status=200,
    )


@require_GET
def readiness(request):
    if not database_is_available():
        return json_status(
            {
                "status": "unavailable",
                "checks": {
                    "database": "unavailable",
                },
            },
            status=503,
        )

    return json_status(
        {
            "status": "ready",
            "checks": {
                "database": "ok",
            },
        },
        status=200,
    )