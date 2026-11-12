"""
NexusCore Authentication & Session Router
Handles login, TOTP MFA validation, and revocable sessions (USER_SESSION).
"""

import hashlib
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
import pyotp
from backend.app.database import get_db
from backend.app.models import AppUser, UserSession, LoginAttempt, Employee
from backend.app.schemas import LoginRequest, TokenResponse, MFASetupResponse, MFAVerifyRequest
from backend.app.security import (
    verify_password, create_access_token, verify_totp, get_current_user
)

router = APIRouter(prefix="/api/auth", tags=["Authentication & Security"])

@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    ip_addr = request.client.host if request.client else "127.0.0.1"
    
    # Support convenient role aliases for testing/demo (admin, pm, dev)
    uname = payload.username.strip()
    alias_map = {"admin": "kavindu", "pm": "dilshan", "dev": "bimsari", "developer": "bimsari", "ceo": "kavindu"}
    effective_username = alias_map.get(uname.lower(), uname)

    # 1. Look up user
    user = db.query(AppUser).filter(AppUser.username == effective_username).first()
    if not user and uname != effective_username:
        user = db.query(AppUser).filter(AppUser.username == uname).first()
    
    if not user:
        # Record failed attempt
        db.add(LoginAttempt(username=payload.username, ip_address=ip_addr, is_success=False, failure_reason="User not found"))
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password.")

    if user.is_locked:
        db.add(LoginAttempt(username=payload.username, ip_address=ip_addr, is_success=False, failure_reason="Account locked"))
        db.commit()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account locked due to security policy. Contact administrator.")

    # 2. Check Password
    if not verify_password(payload.password, user.password_hash):
        user.failed_login_count += 1
        if user.failed_login_count >= 5:
            user.is_locked = True
        db.add(LoginAttempt(username=payload.username, ip_address=ip_addr, is_success=False, failure_reason="Invalid credentials"))
        db.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password.")

    # 3. Check TOTP MFA if enabled
    if user.mfa_enabled:
        if not payload.totp_code:
            return TokenResponse(
                access_token="",
                user_id=user.user_id,
                username=user.username,
                role=user.role,
                mfa_required=True
            )
        if not verify_totp(user.mfa_secret, payload.totp_code):
            db.add(LoginAttempt(username=payload.username, ip_address=ip_addr, is_success=False, failure_reason="MFA code failed"))
            db.commit()
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid TOTP 6-digit verification code.")

    # Reset failed login count
    user.failed_login_count = 0
    
    # 4. Generate Session Token
    token = create_access_token({"sub": user.username, "role": user.role, "user_id": user.user_id})
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    expires_at = datetime.now(timezone.utc) + timedelta(hours=2)

    # 5. Insert USER_SESSION record
    new_session = UserSession(
        user_id=user.user_id,
        token_hash=token_hash,
        ip_address=ip_addr,
        user_agent=request.headers.get("user-agent", "Unknown"),
        expires_at=expires_at,
        is_revoked=False
    )
    db.add(new_session)
    db.add(LoginAttempt(username=payload.username, ip_address=ip_addr, is_success=True))
    db.commit()

    full_name = user.username.title()
    designation = user.role.replace("_", " ").title()
    if user.employee_id:
        emp = db.query(Employee).filter(Employee.employee_id == user.employee_id).first()
        if emp:
            full_name = emp.full_name
            designation = emp.designation
    elif user.role == "client":
        full_name = "CarePlus Client Representative"
        designation = "External Stakeholder"

    return TokenResponse(
        access_token=token,
        user_id=user.user_id,
        username=user.username,
        role=user.role,
        mfa_required=False,
        full_name=full_name,
        designation=designation
    )

@router.post("/mfa/setup", response_model=MFASetupResponse)
def setup_mfa(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(AppUser).filter(AppUser.username == current_user["username"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")
    
    secret = pyotp.random_base32()
    user.mfa_secret = secret
    db.commit()

    totp = pyotp.TOTP(secret)
    provisioning_uri = totp.provisioning_uri(name=user.username, issuer_name="HelaNexus-NexusCore")
    return MFASetupResponse(secret=secret, otpauth_url=provisioning_uri)

@router.post("/mfa/verify")
def verify_mfa_activation(payload: MFAVerifyRequest, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(AppUser).filter(AppUser.username == current_user["username"]).first()
    if not user or not user.mfa_secret:
        raise HTTPException(status_code=400, detail="MFA setup has not been initiated.")
    
    if verify_totp(user.mfa_secret, payload.code):
        user.mfa_enabled = True
        db.commit()
        return {"status": "success", "message": "TOTP Multi-Factor Authentication successfully activated."}
    else:
        raise HTTPException(status_code=400, detail="Invalid verification code.")

@router.get("/me")
def get_user_profile(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(AppUser).filter(AppUser.username == current_user["username"]).first()
    return {
        "username": current_user["username"],
        "role": current_user["role"],
        "mfa_enabled": user.mfa_enabled if user else False
    }
