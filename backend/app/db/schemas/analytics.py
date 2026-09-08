from typing import List, Optional

from pydantic import BaseModel, Field


class DailyCount(BaseModel):
    date: str = Field(description="ISO date YYYY-MM-DD")
    count: int


class StreakAnalytics(BaseModel):
    current_streak: int
    longest_streak: int


class TopEmulsion(BaseModel):
    name: str
    brand: str
    count: int
    percentage: float


class TopHardware(BaseModel):
    name: str
    count: int
    percentage: float


class RankedItem(BaseModel):
    name: str
    count: int
    percentage: float


class LightingInsight(BaseModel):
    golden_hour_percentage: float = Field(
        description="Share of shots taken between 4:00 PM and 6:00 PM local time"
    )
    golden_hour_shots: int
    total_shots: int


class ShootingMatrixTotals(BaseModel):
    total_shots: int
    active_days: int
    period_days: int = 365


class ShootingMatrixResponse(BaseModel):
    matrix: List[DailyCount]
    streaks: StreakAnalytics
    top_emulsion: Optional[TopEmulsion] = None
    top_hardware: Optional[TopHardware] = None
    emulsion_breakdown: List[RankedItem] = Field(default_factory=list)
    hardware_breakdown: List[RankedItem] = Field(default_factory=list)
    lighting_insight: LightingInsight
    totals: ShootingMatrixTotals
    timezone: str = Field(description="IANA timezone used for golden-hour calculation")
