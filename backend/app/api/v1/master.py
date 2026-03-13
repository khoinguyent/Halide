from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import List, Optional
from ...db.session import get_db
from ...db import models
from ...db.schemas.master import FilmStockOut, LensOut, CameraOut

router = APIRouter()

@router.get("/master/films", response_model=List[FilmStockOut])
def get_master_films(
    q: Optional[str] = Query(None, description="Search by name or brand"),
    iso: Optional[int] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.FilmStock)
    if q:
        search = f"%{q}%"
        query = query.filter(or_(
            models.FilmStock.name.ilike(search),
            models.FilmStock.brand.ilike(search)
        ))
    if iso:
        query = query.filter(models.FilmStock.iso == iso)
    return query.all()

@router.get("/master/lenses", response_model=List[LensOut])
def get_master_lenses(
    q: Optional[str] = Query(None, description="Search by model or brand"),
    db: Session = Depends(get_db)
):
    query = db.query(models.Lens)
    if q:
        search = f"%{q}%"
        query = query.filter(or_(
            models.Lens.model.ilike(search),
            models.Lens.brand.ilike(search)
        ))
    return query.all()

@router.get("/master/cameras", response_model=List[CameraOut])
def get_master_cameras(
    q: Optional[str] = Query(None, description="Search by model or brand"),
    db: Session = Depends(get_db)
):
    query = db.query(models.Camera)
    if q:
        search = f"%{q}%"
        query = query.filter(or_(
            models.Camera.model.ilike(search),
            models.Camera.brand.ilike(search)
        ))
    return query.all()
