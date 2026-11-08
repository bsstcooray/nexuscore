"""
NexusCore Configuration Module
Loads environment variables and system defaults.
"""

import os

class Settings:
    APP_NAME: str = "NexusCore API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "True").lower() == "true"
    
    # Database URL: defaults to local sqlite database, easily switched to PostgreSQL
    # Example PostgreSQL: "postgresql+psycopg2://postgres:postgres@localhost:5432/nexuscore_db"
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./nexuscore.db")
    
    # Cryptographic & Security Settings
    SECRET_KEY: str = os.getenv("SECRET_KEY", "nexuscore-cs304-group-ac-super-secret-key-2026")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 120
    
    # Gemini AI API Configuration
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = "gemini-1.5-flash"
    
    # GitHub Integration
    GITHUB_TOKEN: str = os.getenv("GITHUB_TOKEN", "")
    GITHUB_REPO: str = os.getenv("GITHUB_REPO", "HelaNexus/nexus-core-mono")
    
    # PDPA 2022 Monitoring Settings
    TELEMETRY_ALERT_THRESHOLD_SECONDS: int = 300  # 5 minutes

settings = Settings()
