from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from typing import List

import models, schemas, crud, auth
from database import engine, get_db
from firebase_config import init_firebase

# Initialize Firebase
init_firebase()
from strawberry.fastapi import GraphQLRouter
from graphql_schema import schema, get_context

# Make sure tables are created, though Alembic is doing it
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Halide API")

graphql_app = GraphQLRouter(schema, context_getter=get_context)
app.include_router(graphql_app, prefix="/graphql")

@app.post("/register", response_model=schemas.UserOut)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user(db, user_id=user.id)
    if db_user:
        raise HTTPException(status_code=400, detail="User already registered")
    return crud.create_user(db=db, user=user)

@app.post("/login", response_model=schemas.Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # In a real Firebase integration, the frontend sends a Firebase ID token.
    # Here, for typical OAuth2 flow via Swagger, we just verify the user exists by user_id mapped to username
    user = crud.get_user(db, user_id=form_data.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect user ID",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.id}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@app.get("/rolls", response_model=List[schemas.RollOut])
def read_rolls(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    rolls = crud.get_rolls(db, user_id=current_user.id, skip=skip, limit=limit)
    return rolls

@app.post("/rolls", response_model=schemas.RollOut)
def create_roll(roll: schemas.RollCreate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    return crud.create_roll(db=db, roll=roll, user_id=current_user.id)


@app.get("/user_cameras", response_model=List[schemas.UserCameraOut])
def read_user_cameras(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    user_cameras = crud.get_user_cameras(db, user_id=current_user.id, skip=skip, limit=limit)
    return user_cameras

@app.post("/user_cameras", response_model=schemas.UserCameraOut)
def create_user_camera(user_camera: schemas.UserCameraCreate, db: Session = Depends(get_db), current_user: models.User = Depends(auth.get_current_user)):
    return crud.create_user_camera(db=db, user_camera=user_camera, user_id=current_user.id)

@app.get("/")
def read_root():
    return {"message": "Welcome to Halide API"}
