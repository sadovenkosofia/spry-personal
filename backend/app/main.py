import os
from fastapi import FastAPI

from app.api.meetings import router as meetings_router

app = FastAPI(title="spry", docs_url=None, redoc_url=None, openapi_url=None)
app.include_router(meetings_router)
