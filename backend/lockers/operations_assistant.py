"""Read-only, tool-using operations assistant backed by live SmartDrop data."""

import json
import urllib.error
import urllib.request
import uuid
from datetime import timedelta

from django.conf import settings
from django.db.models import Count, Q
from django.utils import timezone

from orders.models import Order

from .models import Drawer, LockerStation


class OperationsAssistantError(Exception):
    pass


TOOLS = [
    {
        "type": "function",
        "name": "get_operations_overview",
        "description": "Read counts of current SmartDrop orders by status and orders waiting longer than two hours.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "type": "function",
        "name": "get_locker_capacity",
        "description": "Read online/offline station and drawer availability counts. Does not return addresses or customer data.",
        "parameters": {"type": "object", "properties": {}},
    },
    {
        "type": "function",
        "name": "get_order_status",
        "description": "Read the operational state of one order using its public UUID. Returns no customer identity or contact details.",
        "parameters": {
            "type": "object",
            "properties": {
                "order_public_id": {
                    "type": "string",
                    "description": "The order's public UUID.",
                }
            },
            "required": ["order_public_id"],
        },
    },
]


def _operations_overview():
    now = timezone.now()
    cutoff = now - timedelta(hours=2)
    statuses = {
        row["status"]: row["count"]
        for row in Order.objects.values("status").annotate(count=Count("id"))
    }
    waiting_orders = Order.objects.filter(
        status__in=(Order.Status.AWAITING_LOCKER, Order.Status.ASSIGNED),
        created_at__lt=cutoff,
    )
    oldest = waiting_orders.order_by("created_at").values_list(
        "created_at", flat=True
    ).first()
    return {
        "order_counts_by_status": statuses,
        "awaiting_locker_or_assigned_over_2h": waiting_orders.count(),
        "oldest_waiting_age_minutes": (
            max(0, int((now - oldest).total_seconds() // 60)) if oldest else None
        ),
        "age_threshold_hours": 2,
        "note": "Two hours is a demo alert threshold, not a configured service-level agreement.",
    }


def _locker_capacity():
    rows = []
    stations = LockerStation.objects.annotate(
        available=Count("drawers", filter=Q(drawers__status=Drawer.Status.AVAILABLE)),
        reserved=Count("drawers", filter=Q(drawers__status=Drawer.Status.RESERVED)),
        occupied=Count("drawers", filter=Q(drawers__status=Drawer.Status.OCCUPIED)),
        out_of_service=Count(
            "drawers", filter=Q(drawers__status=Drawer.Status.OUT_OF_SERVICE)
        ),
    ).order_by("code")[:30]
    for station in stations:
        rows.append(
            {
                "station_code": station.code,
                "station_status": station.status,
                "available_drawers": station.available,
                "reserved_drawers": station.reserved,
                "occupied_drawers": station.occupied,
                "out_of_service_drawers": station.out_of_service,
            }
        )
    return {"stations": rows, "stations_returned": len(rows), "maximum_stations": 30}


def _order_status(arguments):
    try:
        public_id = uuid.UUID(str(arguments.get("order_public_id", "")))
    except (ValueError, TypeError, AttributeError) as error:
        raise ValueError("Provide a valid order public UUID.") from error

    order = (
        Order.objects.select_related("locker_station", "assigned_drawer")
        .filter(public_id=public_id)
        .first()
    )
    if order is None:
        return {"found": False, "message": "No order matches that public UUID."}

    now = timezone.now()
    return {
        "found": True,
        "status": order.status,
        "age_minutes": max(0, int((now - order.created_at).total_seconds() // 60)),
        "assigned_courier": bool(order.assigned_courier_id),
        "locker_code": order.locker_station.code if order.locker_station_id else None,
        "locker_status": order.locker_station.status if order.locker_station_id else None,
        "drawer_number": order.assigned_drawer.number if order.assigned_drawer_id else None,
        "drawer_status": order.assigned_drawer.status if order.assigned_drawer_id else None,
        "ready_for_pickup_at": (
            order.ready_for_pickup_at.isoformat() if order.ready_for_pickup_at else None
        ),
    }


TOOL_HANDLERS = {
    "get_operations_overview": lambda _arguments: _operations_overview(),
    "get_locker_capacity": lambda _arguments: _locker_capacity(),
    "get_order_status": _order_status,
}


def _call_gemini(history):
    api_key = getattr(settings, "GEMINI_API_KEY", "")
    if not api_key:
        raise OperationsAssistantError("The Gemini API key is not configured on the server.")

    model = getattr(settings, "GEMINI_MODEL", "gemini-3.5-flash-lite")
    timeout = getattr(settings, "GEMINI_TIMEOUT_SECONDS", 12)
    request_body = json.dumps(
        {
            "model": model,
            "store": False,
            "input": history,
            "tools": TOOLS,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        "https://generativelanguage.googleapis.com/v1beta/interactions",
        data=request_body,
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raise OperationsAssistantError(
            "Gemini could not complete the request. Check the server API key and model access."
        ) from error
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        raise OperationsAssistantError(
            "Gemini is temporarily unavailable. Try again shortly."
        ) from error


def ask_operations_assistant(question):
    """Ask Gemini to select read-only tools, then ground its answer in their results."""
    history = [
        {
            "type": "user_input",
            "content": [
                {
                    "type": "text",
                    "text": (
                        "You are SmartDrop's operations assistant. Use the provided read-only tools "
                        "to answer from current database facts. Never invent counts, causes, or actions. "
                        "If the tools do not provide enough evidence, say what is missing. Do not issue "
                        "or claim to perform state-changing actions. Keep the answer concise and practical. "
                        "The two-hour waiting threshold is only a demo signal, not an official SLA.\n\n"
                        f"Operator question: {question}"
                    ),
                }
            ],
        }
    ]
    evidence = []

    for _ in range(3):
        interaction = _call_gemini(history)
        steps = interaction.get("steps") or []
        if not isinstance(steps, list):
            raise OperationsAssistantError("Gemini returned an unexpected response.")
        history.extend(steps)
        calls = [step for step in steps if step.get("type") == "function_call"]
        if not calls:
            answer = "\n".join(
                content.get("text", "")
                for step in steps
                if step.get("type") == "model_output"
                for content in step.get("content", [])
                if content.get("type") == "text" and isinstance(content.get("text"), str)
            ).strip()
            if not answer:
                answer = str(interaction.get("output_text", "")).strip()
            if not answer:
                raise OperationsAssistantError("Gemini returned no answer text.")
            return {"answer": answer, "evidence": evidence, "model": getattr(settings, "GEMINI_MODEL", "gemini-3.5-flash-lite")}

        for call in calls:
            tool_name = call.get("name")
            handler = TOOL_HANDLERS.get(tool_name)
            if handler is None:
                raise OperationsAssistantError("Gemini requested an unavailable operation.")
            arguments = call.get("arguments", {})
            if isinstance(arguments, str):
                try:
                    arguments = json.loads(arguments)
                except json.JSONDecodeError as error:
                    raise OperationsAssistantError("Gemini returned invalid tool arguments.") from error
            if not isinstance(arguments, dict):
                raise OperationsAssistantError("Gemini returned invalid tool arguments.")
            result = handler(arguments)
            evidence.append({"tool": tool_name, "data": result})
            history.append(
                {
                    "type": "function_result",
                    "name": tool_name,
                    "call_id": call.get("id"),
                    "result": [{"type": "text", "text": json.dumps(result)}],
                }
            )

    raise OperationsAssistantError("The assistant reached its tool-call limit. Narrow the question and try again.")
