"""
FoodPulse – Performance Tracking Service.

Backend automatically collects and aggregates trial metrics:
  - Daily orders and revenue
  - Average rating
  - Repeat purchases
  - Cancellation rate

Aggregation is computed server-side — no calculation in the frontend.
"""

from __future__ import annotations

from fastapi import HTTPException, status

from ..repository import MetricsRepository, TrialRepository
from ..schemas import (
    RecordMetricRequest,
    TrialMetric,
    TrialAnalytics,
    TrialStatus,
)


class PerformanceService:
    """Records and aggregates trial performance metrics."""

    @staticmethod
    def record_metric(trial_id: str, payload: RecordMetricRequest) -> TrialMetric:
        """
        Records one day's performance metrics for a trial.
        Idempotent — duplicate records for the same trial+date are merged.
        """
        trial = TrialRepository.get_by_id(trial_id)
        if not trial:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Trial '{trial_id}' not found.",
            )

        if trial.status not in (TrialStatus.active, TrialStatus.completed):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot record metrics for a trial with status '{trial.status}'.",
            )

        return MetricsRepository.record(trial_id, payload)

    @staticmethod
    def get_analytics(trial_id: str) -> TrialAnalytics:
        """
        Returns aggregated analytics for the given trial.
        All aggregation is performed here in the backend.
        """
        trial = TrialRepository.get_by_id(trial_id)
        if not trial:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Trial '{trial_id}' not found.",
            )

        daily_metrics = MetricsRepository.list_for_trial(trial_id)

        if not daily_metrics:
            return TrialAnalytics(
                trial_id=trial_id,
                trial_name=trial.suggestion_name,
                status=trial.status,
                total_orders=0,
                total_revenue=0,
                avg_daily_orders=0.0,
                avg_rating=0.0,
                total_repeat_purchases=0,
                avg_cancellation_rate=0.0,
                predicted_daily_orders=trial.predicted_daily_orders,
                performance_vs_prediction_pct=0.0,
                daily_breakdown=[],
            )

        # Aggregate
        total_orders        = sum(m.orders for m in daily_metrics)
        total_revenue       = sum(m.revenue for m in daily_metrics)
        total_repeat        = sum(m.repeat_purchases for m in daily_metrics)
        days                = len(daily_metrics)
        avg_daily_orders    = round(total_orders / days, 2)
        avg_rating          = round(sum(m.avg_rating for m in daily_metrics) / days, 2)
        avg_cancel_rate     = round(sum(m.cancellation_rate for m in daily_metrics) / days, 4)

        # Performance vs prediction
        predicted           = trial.predicted_daily_orders
        perf_pct = round((avg_daily_orders / predicted * 100), 2) if predicted > 0 else 0.0

        return TrialAnalytics(
            trial_id=trial_id,
            trial_name=trial.suggestion_name,
            status=trial.status,
            total_orders=total_orders,
            total_revenue=total_revenue,
            avg_daily_orders=avg_daily_orders,
            avg_rating=avg_rating,
            total_repeat_purchases=total_repeat,
            avg_cancellation_rate=avg_cancel_rate,
            predicted_daily_orders=predicted,
            performance_vs_prediction_pct=perf_pct,
            daily_breakdown=daily_metrics,
        )
