from fastapi import FastAPI
from strawberry.fastapi import GraphQLRouter

from .api.v1 import auth, gear, rolls, storage
from .graphql.schema import schema, get_context
from .core.firebase import init_firebase
from .db.base import Base
from .db.session import engine

# Initialize Firebase
init_firebase()

# Note: In production, migrations should be handled by Alembic. 
# This is a fallback for initial setup/dev.
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Halide API")

# REST Routers
app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(gear.router, prefix="/api/v1", tags=["Gear"])
app.include_router(rolls.router, prefix="/api/v1", tags=["Rolls"])
app.include_router(storage.router, prefix="/api/v1", tags=["Storage"])

# GraphQL Router
graphql_app = GraphQLRouter(schema, context_getter=get_context)
app.include_router(graphql_app, prefix="/graphql")

@app.get("/")
def read_root():
    return {"message": "Welcome to Halide API - Modular Version"}
