from fastapi import FastAPI
from strawberry.fastapi import GraphQLRouter

from .api.v1 import auth, gear, rolls, storage, master, dashboard, user, billing
from .graphql.schema import schema, get_context
from .core.firebase import init_firebase
from .db.base import Base
from .db.session import engine
from .db import models  # noqa: F401 - ensure all models registered before create_all

# Initialize Firebase
init_firebase()

# Note: In production, migrations should be handled by Alembic. 
# This is a fallback so all current models have tables if migrations not run.
Base.metadata.create_all(bind=engine)

from .tasks.transfer_worker import start_worker, stop_worker

app = FastAPI(title="Halide API")

@app.on_event("startup")
def startup_event():
    start_worker()

@app.on_event("shutdown")
def shutdown_event():
    stop_worker()
# REST Routers
app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(gear.router, prefix="/api/v1", tags=["Gear"])
app.include_router(rolls.router, prefix="/api/v1", tags=["Rolls"])
app.include_router(storage.router, prefix="/api/v1", tags=["Storage"])
app.include_router(master.router, prefix="/api/v1", tags=["Master Data"])
app.include_router(dashboard.router, prefix="/api/v1", tags=["Dashboard"])
app.include_router(user.router, prefix="/api/v1/user", tags=["User Profile"])
app.include_router(billing.router, prefix="/api/v1/billing", tags=["Billing"])

# GraphQL Router
graphql_app = GraphQLRouter(schema, context_getter=get_context)
app.include_router(graphql_app, prefix="/graphql")

@app.get("/")
def read_root():
    return {"message": "Welcome to Halide API - Modular Version"}
