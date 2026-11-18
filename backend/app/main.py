import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.meetings import router as meetings_router

app = FastAPI(title="spry", docs_url=None, redoc_url=None, openapi_url=None)
app.include_router(meetings_router)

# Lab 9: the frontend on Firebase Hosting calls this API from another origin.
# Override with CORS_ORIGINS="https://a.example,https://b.example"; an empty value disables CORS.
_DEFAULT_ORIGINS = "https://avid-sphere-510417-m1.web.app,https://avid-sphere-510417-m1.firebaseapp.com"
_origins = [o.strip() for o in os.environ.get("CORS_ORIGINS", _DEFAULT_ORIGINS).split(",") if o.strip()]
if _origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_origins,
        allow_methods=["GET", "POST", "PUT"],
        allow_headers=["Content-Type"],
    )
