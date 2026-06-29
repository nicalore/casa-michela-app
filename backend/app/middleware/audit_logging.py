import json
import logging
import os
from datetime import datetime
from typing import Callable
from zoneinfo import ZoneInfo

import jwt
from fastapi import Request, Response

from app.db.session import AsyncSessionLocal
from app.repositories.account_repository import AccountRepository

LOG_FILE_TEMPLATE = os.getenv("AUDIT_LOG_PATH", "./logs/audit_{date}.log")
LOG_DIR           = os.path.dirname(LOG_FILE_TEMPLATE)

if LOG_DIR and not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR, exist_ok=True)

class DateRotatingFileHandler(logging.FileHandler):
    def __init__(self, filename_template, *args, **kwargs):
        self.filename_template = filename_template
        super().__init__(self._get_filename(), *args, **kwargs)

    def _get_filename(self):
        date_str = datetime.now(ZoneInfo("Europe/Rome")).strftime("%Y-%m-%d")
        return self.filename_template.format(date=date_str)

    def emit(self, record):
        new_filename = self._get_filename()
        if self.baseFilename != os.path.abspath(new_filename):
            self.close()
            self.baseFilename = os.path.abspath(new_filename)
            self.stream = self._open()
        super().emit(record)

logger = logging.getLogger("audit")
logger.setLevel(logging.INFO)

file_handler = DateRotatingFileHandler(LOG_FILE_TEMPLATE, encoding="utf-8")
formatter    = logging.Formatter("%(message)s")
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

def log_audit_operation(user_id: str, operation_type: str, status: str, target: str = "") -> None:
    timestamp   = datetime.now(ZoneInfo("Europe/Rome")).isoformat(timespec="milliseconds")
    log_message = f"{timestamp}\t{user_id}\t{operation_type}\t{status}\t{target}"
    
    logger.info(log_message)

async def _resolve_tax_code_from_db(username: str | None = None, email: str | None = None) -> str:
    try:
        async with AsyncSessionLocal() as session:
            repo = AccountRepository(session)
            
            if username:
                account = await repo.get_by_username(username)
            elif email:
                account = await repo.get_by_email(email)
            else:
                account = None
                
            return account.tax_code if account else (username or email or "anonymous")
            
    except Exception:
        return username or email or "anonymous"

async def extract_user_id(request: Request) -> str:
    user_id     = "anonymous"
    auth_header = request.headers.get("Authorization")
    
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
        try:
            payload = jwt.decode(
                token, 
                options=
                {
                    "verify_signature": False
                }
            )
            return str(payload.get("sub", "anonymous"))
        except Exception:
            pass

    try:
        body_bytes = await request.body()
        
        if body_bytes:
            async def receive():
                return \
                {
                    "type": "http.request",
                    "body": body_bytes
                }
            
            request._receive = receive
            payload          = json.loads(body_bytes)
            path             = request.url.path

            if "/auth/login" in path:
                username = payload.get("username")
                if username:
                    user_id = await _resolve_tax_code_from_db(username=username)
                    
            elif "/auth/logout" in path:
                refresh_token = payload.get("refresh_token")
                if refresh_token:
                    rt_payload = jwt.decode(
                        refresh_token, 
                        options=
                        {
                            "verify_signature": False
                        }
                    )
                    user_id    = rt_payload.get("sub", "anonymous")
                    
            elif "/auth/change-password" in path:
                refresh_token = payload.get("refresh_token")
                if refresh_token:
                    rt_payload = jwt.decode(
                        refresh_token, 
                        options=
                        {
                            "verify_signature": False
                        }
                    )
                    user_id    = rt_payload.get("sub", "anonymous")
                    
            elif "/auth/request-password-reset" in path:
                email = payload.get("email")
                if email:
                    user_id = await _resolve_tax_code_from_db(email=email)
                    
            elif "/auth/reset-password" in path:
                reset_token = payload.get("token")
                if reset_token:
                    tk_payload = jwt.decode(
                        reset_token, 
                        options=
                        {
                            "verify_signature": False
                        }
                    )
                    user_id    = tk_payload.get("sub", "anonymous")
                    
    except Exception:
        pass
            
    return str(user_id)

async def audit_logging_middleware(request: Request, call_next: Callable) -> Response:
    if request.method == "OPTIONS":
        return await call_next(request)

    user_id = await extract_user_id(request)

    response = await call_next(request)
    
    path           = request.url.path
    operation_type = None
    target         = ""
    status         = "Success" if response.status_code < 400 else "Failure"
    
    response_body = b""
    if status == "Success" and request.method in ["POST", "PUT", "PATCH"]:
        resp_body = [section async for section in response.body_iterator]
        response_body = b"".join(resp_body)
        response      = Response(
            content=response_body,
            status_code=response.status_code,
            headers=dict(response.headers),
            media_type=response.media_type
        )
    
    if "/auth/login" in path:
        operation_type = "Authentication"
        if response.status_code == 423:
            log_audit_operation(user_id, "Account Lockout", "System", target)
            status = "Failure"
            
    elif "/auth/logout" in path:
        operation_type = "Logout"
        
    elif "/auth/change-password" in path:
        operation_type = "Password Change"

    elif "/auth/request-password-reset" in path:
        operation_type = "Password Reset Request"

    elif "/auth/reset-password" in path:
        operation_type = "Password Reset"
        
    elif "/people" in path:
        if request.method == "POST":
            operation_type = "Person creation"
            if status == "Success":
                try:
                    data   = json.loads(response_body)
                    target = data.get("tax_code", "")
                except Exception:
                    pass
        elif request.method in ["PUT", "PATCH"]:
            operation_type = "Person modification"
            parts          = path.split("/")
            if len(parts) > 2:
                target = parts[2]
                
    elif any(entity in path for entity in ["/subjects", "/schools", "/study-programs", "/teaching-offerings", "/association-subjects", "/ministry-subjects"]):
        entity_map = \
        {
            "/subjects":             "Subject",
            "/schools":              "School",
            "/study-programs":       "Study program",
            "/teaching-offerings":   "Teaching offering",
            "/association-subjects": "Association subject",
            "/ministry-subjects":    "Ministry subject"
        }
        
        entity_type = next((val for key, val in entity_map.items() if key in path), None)
        
        if entity_type:
            if request.method == "POST":
                operation_type = f"{entity_type} creation"
                if status == "Success":
                    try:
                        data   = json.loads(response_body)
                        target = data.get("id", "")
                    except Exception:
                        pass
            elif request.method in ["PUT", "PATCH"]:
                operation_type = f"{entity_type} modification"
                parts          = path.split("/")
                target         = parts[-1]
            elif request.method == "DELETE":
                operation_type = f"{entity_type} elimination"
                parts          = path.split("/")
                target         = parts[-1]

    if operation_type:
        log_audit_operation(
            user_id=user_id,
            operation_type=operation_type,
            status=status,
            target=str(target)
        )

    return response