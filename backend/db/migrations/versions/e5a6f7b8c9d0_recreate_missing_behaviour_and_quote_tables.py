"""recreate missing behaviour and quote tables

Revision ID: e5a6f7b8c9d0
Revises: 394da2cfd515
Create Date: 2026-09-11 19:36:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e5a6f7b8c9d0'
down_revision: Union[str, Sequence[str], None] = '394da2cfd515'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. shift_behaviour_summaries
    op.create_table(
        'shift_behaviour_summaries',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('shift_id', sa.UUID(), nullable=False),
        sa.Column('rider_id', sa.UUID(), nullable=False),
        sa.Column('duration_seconds', sa.Integer(), nullable=False),
        sa.Column('distance_km', sa.Numeric(precision=8, scale=2), nullable=False),
        sa.Column('sample_count', sa.Integer(), nullable=False),
        sa.Column('average_speed', sa.Float(), nullable=False),
        sa.Column('max_speed', sa.Float(), nullable=False),
        sa.Column('hard_braking_count', sa.Integer(), nullable=False),
        sa.Column('hard_acceleration_count', sa.Integer(), nullable=False),
        sa.Column('overspeeding_count', sa.Integer(), nullable=False),
        sa.Column('sharp_turn_count', sa.Integer(), nullable=False),
        sa.Column('hard_braking_rate', sa.Float(), nullable=False),
        sa.Column('hard_acceleration_rate', sa.Float(), nullable=False),
        sa.Column('overspeeding_rate', sa.Float(), nullable=False),
        sa.Column('sharp_turn_rate', sa.Float(), nullable=False),
        sa.Column('max_g', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('accel_std', sa.Float(), nullable=False),
        sa.Column('jerk_mean', sa.Float(), nullable=False),
        sa.Column('sampling_density', sa.Float(), nullable=False),
        sa.Column('data_quality_score', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('is_valid', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('data_quality_score >= 0 AND data_quality_score <= 1', name='ck_shift_behaviour_summaries_quality_score_range'),
        sa.CheckConstraint('distance_km >= 0', name='ck_shift_behaviour_summaries_distance_non_negative'),
        sa.CheckConstraint('duration_seconds >= 0', name='ck_shift_behaviour_summaries_duration_non_negative'),
        sa.CheckConstraint('sample_count >= 0', name='ck_shift_behaviour_summaries_sample_count_non_negative'),
        sa.ForeignKeyConstraint(['rider_id'], ['users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['shift_id'], ['shifts.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_shift_behaviour_summaries_rider_id'), 'shift_behaviour_summaries', ['rider_id'], unique=False)
    op.create_index(op.f('ix_shift_behaviour_summaries_shift_id'), 'shift_behaviour_summaries', ['shift_id'], unique=True)

    # 2. rider_behaviour_profiles
    op.create_table(
        'rider_behaviour_profiles',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('rider_id', sa.UUID(), nullable=False),
        sa.Column('computed_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('based_on_shift_count', sa.Integer(), nullable=False),
        sa.Column('based_on_valid_shift_count', sa.Integer(), nullable=False),
        sa.Column('recent_avg_speed', sa.Float(), nullable=False),
        sa.Column('recent_max_speed', sa.Float(), nullable=False),
        sa.Column('recent_hard_braking_rate', sa.Float(), nullable=False),
        sa.Column('recent_hard_acceleration_rate', sa.Float(), nullable=False),
        sa.Column('recent_overspeeding_rate', sa.Float(), nullable=False),
        sa.Column('recent_sharp_turn_rate', sa.Float(), nullable=False),
        sa.Column('recent_max_g', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('recent_data_quality', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('medium_avg_speed', sa.Float(), nullable=False),
        sa.Column('medium_max_speed', sa.Float(), nullable=False),
        sa.Column('medium_hard_braking_rate', sa.Float(), nullable=False),
        sa.Column('medium_hard_acceleration_rate', sa.Float(), nullable=False),
        sa.Column('medium_overspeeding_rate', sa.Float(), nullable=False),
        sa.Column('medium_sharp_turn_rate', sa.Float(), nullable=False),
        sa.Column('medium_max_g', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('medium_data_quality', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('long_term_avg_speed', sa.Float(), nullable=False),
        sa.Column('long_term_max_speed', sa.Float(), nullable=False),
        sa.Column('long_term_hard_braking_rate', sa.Float(), nullable=False),
        sa.Column('long_term_hard_acceleration_rate', sa.Float(), nullable=False),
        sa.Column('long_term_overspeeding_rate', sa.Float(), nullable=False),
        sa.Column('long_term_sharp_turn_rate', sa.Float(), nullable=False),
        sa.Column('long_term_max_g', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('long_term_data_quality', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('hard_braking_rate_variance', sa.Float(), nullable=False),
        sa.Column('overspeeding_rate_variance', sa.Float(), nullable=False),
        sa.Column('speed_variability', sa.Float(), nullable=False),
        sa.Column('behaviour_consistency_score', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('overall_behaviour_score', sa.Numeric(precision=5, scale=2), nullable=False),
        sa.Column('data_quality_score', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('confidence', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('based_on_shift_count >= 0', name='ck_rider_behaviour_profiles_shift_count_non_negative'),
        sa.CheckConstraint('based_on_valid_shift_count <= based_on_shift_count', name='ck_rider_behaviour_profiles_valid_le_total'),
        sa.CheckConstraint('based_on_valid_shift_count >= 0', name='ck_rider_behaviour_profiles_valid_shift_count_non_negative'),
        sa.CheckConstraint('behaviour_consistency_score >= 0 AND behaviour_consistency_score <= 100', name='ck_rider_behaviour_profiles_consistency_score_range'),
        sa.CheckConstraint('confidence >= 0 AND confidence <= 1', name='ck_rider_behaviour_profiles_confidence_range'),
        sa.CheckConstraint('data_quality_score >= 0 AND data_quality_score <= 1', name='ck_rider_behaviour_profiles_data_quality_range'),
        sa.CheckConstraint('overall_behaviour_score >= 0 AND overall_behaviour_score <= 100', name='ck_rider_behaviour_profiles_overall_score_range'),
        sa.ForeignKeyConstraint(['rider_id'], ['users.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_rider_behaviour_profiles_rider_id'), 'rider_behaviour_profiles', ['rider_id'], unique=True)

    # 3. premium_quotes
    op.create_table(
        'premium_quotes',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('shift_id', sa.UUID(), nullable=False),
        sa.Column('rider_id', sa.UUID(), nullable=False),
        sa.Column('is_cold_start', sa.Boolean(), nullable=False),
        sa.Column('risk_score', sa.Numeric(precision=5, scale=2), nullable=True),
        sa.Column('risk_band', sa.String(length=20), nullable=True),
        sa.Column('confidence', sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column('scoring_method', sa.String(length=50), nullable=False),
        sa.Column('model_version', sa.String(length=100), nullable=False),
        sa.Column('pricing_mode', sa.String(length=30), nullable=False),
        sa.Column('base_premium', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('previous_premium', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('adjustment_amount', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('final_premium', sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column('rate_of_change_capped', sa.Boolean(), nullable=False),
        sa.Column('explanation', sa.Text(), nullable=False),
        sa.Column('computed_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('base_premium >= 0', name='ck_premium_quotes_base_premium_non_negative'),
        sa.CheckConstraint('confidence >= 0 AND confidence <= 1', name='ck_premium_quotes_confidence_range'),
        sa.CheckConstraint('final_premium >= 0', name='ck_premium_quotes_final_premium_non_negative'),
        sa.CheckConstraint('risk_score IS NULL OR (risk_score >= 0 AND risk_score <= 100)', name='ck_premium_quotes_risk_score_range'),
        sa.ForeignKeyConstraint(['rider_id'], ['users.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['shift_id'], ['shifts.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_premium_quotes_rider_id'), 'premium_quotes', ['rider_id'], unique=False)
    op.create_index(op.f('ix_premium_quotes_shift_id'), 'premium_quotes', ['shift_id'], unique=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_premium_quotes_shift_id'), table_name='premium_quotes')
    op.drop_index(op.f('ix_premium_quotes_rider_id'), table_name='premium_quotes')
    op.drop_table('premium_quotes')
    op.drop_index(op.f('ix_rider_behaviour_profiles_rider_id'), table_name='rider_behaviour_profiles')
    op.drop_table('rider_behaviour_profiles')
    op.drop_index(op.f('ix_shift_behaviour_summaries_shift_id'), table_name='shift_behaviour_summaries')
    op.drop_index(op.f('ix_shift_behaviour_summaries_rider_id'), table_name='shift_behaviour_summaries')
    op.drop_table('shift_behaviour_summaries')
