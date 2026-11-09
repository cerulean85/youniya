"""토스페이먼츠 결제 API (API 개별 연동). https://docs.tosspayments.com/reference

The secret key is sent as HTTP Basic (`<secret>:`), from the server only."""

import base64

import httpx

BASE = "https://api.tosspayments.com/v1"


class TossError(Exception):
    """Toss refused: `code` and `message` are Toss's own (shown to the payer as they are)."""

    def __init__(self, status: int, code: str, message: str):
        super().__init__(f"{status} {code}: {message}")
        self.status, self.code, self.message = status, code, message


class TossClient:
    def __init__(self, secret_key: str, base: str = BASE, timeout: float = 30):
        token = base64.b64encode(f"{secret_key}:".encode()).decode()
        self.headers = {"Authorization": f"Basic {token}", "Content-Type": "application/json"}
        self.base, self.timeout = base, timeout

    def _call(self, method: str, path: str, json: dict | None = None, idempotency_key: str | None = None) -> dict:
        headers = self.headers | ({"Idempotency-Key": idempotency_key} if idempotency_key else {})
        r = httpx.request(method, f"{self.base}{path}", headers=headers, json=json, timeout=self.timeout)
        if r.status_code >= 400:
            try:
                body = r.json()
            except ValueError:
                body = {}
            raise TossError(r.status_code, body.get("code", "UNKNOWN_ERROR"),
                            body.get("message", "결제를 처리하지 못했어요."))
        return r.json()

    def confirm(self, payment_key: str, order_id: str, amount: int) -> dict:
        return self._call("POST", "/payments/confirm",
                          {"paymentKey": payment_key, "orderId": order_id, "amount": amount})

    def payment(self, payment_key: str) -> dict:
        return self._call("GET", f"/payments/{payment_key}")

    def cancel(self, payment_key: str, reason: str, idempotency_key: str) -> dict:
        return self._call("POST", f"/payments/{payment_key}/cancel", {"cancelReason": reason},
                          idempotency_key=idempotency_key)
