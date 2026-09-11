BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 653c1f96e4dd

CREATE TYPE user_role_enum AS ENUM ('RIDER', 'ADMIN', 'INSURER', 'SUPPORT');

CREATE TABLE users (
    id UUID NOT NULL, 
    email VARCHAR(255) NOT NULL, 
    phone_number VARCHAR(30) NOT NULL, 
    hashed_password VARCHAR(255) NOT NULL, 
    full_name VARCHAR(255) NOT NULL, 
    role user_role_enum NOT NULL, 
    is_active BOOLEAN NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    UNIQUE (phone_number)
);

CREATE UNIQUE INDEX ix_users_email ON users (email);

CREATE TABLE rider_profiles (
    id UUID NOT NULL, 
    user_id UUID NOT NULL, 
    vehicle_type VARCHAR(50) NOT NULL, 
    license_number VARCHAR(100), 
    emergency_contact_phone VARCHAR(30), 
    safety_rating NUMERIC(3, 2) NOT NULL, 
    kyc_status VARCHAR(50) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX ix_rider_profiles_user_id ON rider_profiles (user_id);

CREATE TYPE shift_status_enum AS ENUM ('ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED');

CREATE TABLE shifts (
    id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    status shift_status_enum NOT NULL, 
    start_time TIMESTAMP WITH TIME ZONE NOT NULL, 
    end_time TIMESTAMP WITH TIME ZONE, 
    distance_km NUMERIC(8, 2) NOT NULL, 
    premium_amount NUMERIC(10, 2) NOT NULL, 
    policy_number VARCHAR(100), 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE CASCADE, 
    UNIQUE (policy_number)
);

CREATE INDEX ix_shifts_rider_id ON shifts (rider_id);

CREATE INDEX ix_shifts_status ON shifts (status);

CREATE TYPE risk_level_enum AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

CREATE TABLE risk_scores (
    id UUID NOT NULL, 
    shift_id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    risk_score NUMERIC(5, 2) NOT NULL, 
    risk_level risk_level_enum NOT NULL, 
    hard_braking_count INTEGER NOT NULL, 
    hard_acceleration_count INTEGER NOT NULL, 
    overspeeding_count INTEGER NOT NULL, 
    window_start TIMESTAMP WITH TIME ZONE NOT NULL, 
    window_end TIMESTAMP WITH TIME ZONE NOT NULL, 
    evaluated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE CASCADE
);

CREATE INDEX ix_risk_scores_rider_id ON risk_scores (rider_id);

CREATE INDEX ix_risk_scores_risk_level ON risk_scores (risk_level);

CREATE INDEX ix_risk_scores_shift_id ON risk_scores (shift_id);

CREATE TABLE telemetry_batches (
    id UUID NOT NULL, 
    shift_id UUID NOT NULL, 
    redis_stream_id VARCHAR(100), 
    batch_sequence INTEGER NOT NULL, 
    sample_count INTEGER NOT NULL, 
    start_timestamp TIMESTAMP WITH TIME ZONE NOT NULL, 
    end_timestamp TIMESTAMP WITH TIME ZONE NOT NULL, 
    ingested_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE CASCADE, 
    UNIQUE (redis_stream_id), 
    CONSTRAINT uq_telemetry_batches_shift_sequence UNIQUE (shift_id, batch_sequence)
);

CREATE INDEX ix_telemetry_batches_shift_id ON telemetry_batches (shift_id);

CREATE TYPE incident_status_enum AS ENUM ('DETECTED', 'PENDING_VERIFICATION', 'VERIFIED_ACCIDENT', 'FALSE_POSITIVE', 'DISCARDED');

CREATE TABLE incidents (
    id UUID NOT NULL, 
    shift_id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    batch_id UUID, 
    status incident_status_enum NOT NULL, 
    detected_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    peak_g_force NUMERIC(5, 2) NOT NULL, 
    confidence_score NUMERIC(3, 2) NOT NULL, 
    latitude FLOAT NOT NULL, 
    longitude FLOAT NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(batch_id) REFERENCES telemetry_batches (id) ON DELETE SET NULL, 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE CASCADE
);

CREATE INDEX ix_incidents_rider_id ON incidents (rider_id);

CREATE INDEX ix_incidents_shift_id ON incidents (shift_id);

CREATE INDEX ix_incidents_status ON incidents (status);

CREATE TABLE telemetry_samples (
    id UUID NOT NULL, 
    batch_id UUID NOT NULL, 
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL, 
    latitude FLOAT NOT NULL, 
    longitude FLOAT NOT NULL, 
    altitude FLOAT, 
    gps_accuracy FLOAT, 
    speed FLOAT NOT NULL, 
    accel_x FLOAT NOT NULL, 
    accel_y FLOAT NOT NULL, 
    accel_z FLOAT NOT NULL, 
    gyro_x FLOAT NOT NULL, 
    gyro_y FLOAT NOT NULL, 
    gyro_z FLOAT NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(batch_id) REFERENCES telemetry_batches (id) ON DELETE CASCADE
);

CREATE INDEX idx_telemetry_samples_batch_timestamp ON telemetry_samples (batch_id, timestamp);

CREATE INDEX ix_telemetry_samples_batch_id ON telemetry_samples (batch_id);

CREATE INDEX ix_telemetry_samples_timestamp ON telemetry_samples (timestamp);

CREATE TYPE claim_status_enum AS ENUM ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'PAID');

CREATE TABLE claims (
    id UUID NOT NULL, 
    incident_id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    shift_id UUID NOT NULL, 
    claim_number VARCHAR(100) NOT NULL, 
    status claim_status_enum NOT NULL, 
    claimed_amount NUMERIC(10, 2) NOT NULL, 
    approved_amount NUMERIC(10, 2), 
    rejection_reason TEXT, 
    filed_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(incident_id) REFERENCES incidents (id) ON DELETE CASCADE, 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE CASCADE, 
    UNIQUE (claim_number)
);

CREATE UNIQUE INDEX ix_claims_incident_id ON claims (incident_id);

CREATE INDEX ix_claims_rider_id ON claims (rider_id);

CREATE INDEX ix_claims_shift_id ON claims (shift_id);

CREATE INDEX ix_claims_status ON claims (status);

CREATE TABLE audit_events (
    id UUID NOT NULL, 
    claim_id UUID, 
    performed_by_user_id UUID NOT NULL, 
    event_type VARCHAR(100) NOT NULL, 
    old_state VARCHAR(50), 
    new_state VARCHAR(50), 
    metadata_json JSONB, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(claim_id) REFERENCES claims (id) ON DELETE CASCADE, 
    FOREIGN KEY(performed_by_user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_audit_events_claim_id ON audit_events (claim_id);

CREATE TABLE incident_evidence (
    id UUID NOT NULL, 
    incident_id UUID NOT NULL, 
    claim_id UUID, 
    file_url TEXT NOT NULL, 
    file_type VARCHAR(50) NOT NULL, 
    file_hash VARCHAR(64), 
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(claim_id) REFERENCES claims (id) ON DELETE CASCADE, 
    FOREIGN KEY(incident_id) REFERENCES incidents (id) ON DELETE CASCADE
);

CREATE INDEX ix_incident_evidence_claim_id ON incident_evidence (claim_id);

CREATE INDEX ix_incident_evidence_incident_id ON incident_evidence (incident_id);

CREATE TYPE payment_type_enum AS ENUM ('PREMIUM_COLLECTION', 'CLAIM_PAYOUT');

CREATE TYPE payment_status_enum AS ENUM ('PENDING', 'PROCESSING', 'SUCCESSFUL', 'FAILED', 'REFUNDED');

CREATE TABLE payments (
    id UUID NOT NULL, 
    shift_id UUID, 
    claim_id UUID, 
    rider_id UUID NOT NULL, 
    payment_type payment_type_enum NOT NULL, 
    amount NUMERIC(10, 2) NOT NULL, 
    currency VARCHAR(3) NOT NULL, 
    status payment_status_enum NOT NULL, 
    transaction_ref VARCHAR(100), 
    processed_at TIMESTAMP WITH TIME ZONE, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(claim_id) REFERENCES claims (id) ON DELETE SET NULL, 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE CASCADE, 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE SET NULL, 
    UNIQUE (transaction_ref)
);

CREATE INDEX ix_payments_claim_id ON payments (claim_id);

CREATE INDEX ix_payments_rider_id ON payments (rider_id);

CREATE INDEX ix_payments_shift_id ON payments (shift_id);

CREATE INDEX ix_payments_status ON payments (status);

INSERT INTO alembic_version (version_num) VALUES ('653c1f96e4dd') RETURNING alembic_version.version_num;

-- Running upgrade 653c1f96e4dd -> 1c70384e9a27

ALTER TABLE audit_events ADD COLUMN entity_type VARCHAR(50) NOT NULL;

ALTER TABLE audit_events ADD COLUMN entity_id UUID NOT NULL;

ALTER TABLE audit_events DROP CONSTRAINT audit_events_claim_id_fkey;

ALTER TABLE audit_events DROP CONSTRAINT audit_events_performed_by_user_id_fkey;

ALTER TABLE audit_events ADD FOREIGN KEY(performed_by_user_id) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE audit_events ADD FOREIGN KEY(claim_id) REFERENCES claims (id) ON DELETE SET NULL;

ALTER TABLE claims DROP CONSTRAINT claims_rider_id_fkey;

ALTER TABLE claims DROP CONSTRAINT claims_shift_id_fkey;

ALTER TABLE claims DROP CONSTRAINT claims_incident_id_fkey;

ALTER TABLE claims ADD FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE RESTRICT;

ALTER TABLE claims ADD FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE claims ADD FOREIGN KEY(incident_id) REFERENCES incidents (id) ON DELETE RESTRICT;

ALTER TABLE claims ADD CONSTRAINT ck_claims_approved_amount_non_negative CHECK (approved_amount IS NULL OR approved_amount >= 0);

ALTER TABLE claims ADD CONSTRAINT ck_claims_claimed_amount_non_negative CHECK (claimed_amount >= 0);

ALTER TABLE incident_evidence DROP CONSTRAINT incident_evidence_incident_id_fkey;

ALTER TABLE incident_evidence DROP CONSTRAINT incident_evidence_claim_id_fkey;

ALTER TABLE incident_evidence ADD FOREIGN KEY(claim_id) REFERENCES claims (id) ON DELETE SET NULL;

ALTER TABLE incident_evidence ADD FOREIGN KEY(incident_id) REFERENCES incidents (id) ON DELETE RESTRICT;

ALTER TABLE incidents DROP CONSTRAINT incidents_shift_id_fkey;

ALTER TABLE incidents DROP CONSTRAINT incidents_rider_id_fkey;

ALTER TABLE incidents ADD FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE RESTRICT;

ALTER TABLE incidents ADD FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE incidents ADD CONSTRAINT ck_incidents_confidence_score_range CHECK (confidence_score >= 0 AND confidence_score <= 1);

ALTER TABLE incidents ADD CONSTRAINT ck_incidents_peak_g_force_non_negative CHECK (peak_g_force >= 0);

ALTER TABLE payments DROP CONSTRAINT payments_rider_id_fkey;

ALTER TABLE payments ADD FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE payments ADD CONSTRAINT ck_payments_amount_non_negative CHECK (amount >= 0);

ALTER TABLE payments ADD CONSTRAINT ck_payments_type_linkage CHECK ((payment_type = 'PREMIUM_COLLECTION' AND shift_id IS NOT NULL) OR (payment_type = 'CLAIM_PAYOUT' AND claim_id IS NOT NULL));

ALTER TABLE rider_profiles ADD CONSTRAINT ck_rider_profiles_safety_rating_range CHECK (safety_rating >= 1.00 AND safety_rating <= 5.00);

ALTER TABLE risk_scores DROP CONSTRAINT risk_scores_rider_id_fkey;

ALTER TABLE risk_scores DROP CONSTRAINT risk_scores_shift_id_fkey;

ALTER TABLE risk_scores ADD FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE RESTRICT;

ALTER TABLE risk_scores ADD FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE risk_scores ADD CONSTRAINT ck_risk_scores_hard_acceleration_non_negative CHECK (hard_acceleration_count >= 0);

ALTER TABLE risk_scores ADD CONSTRAINT ck_risk_scores_hard_braking_non_negative CHECK (hard_braking_count >= 0);

ALTER TABLE risk_scores ADD CONSTRAINT ck_risk_scores_overspeeding_non_negative CHECK (overspeeding_count >= 0);

ALTER TABLE risk_scores ADD CONSTRAINT ck_risk_scores_score_range CHECK (risk_score >= 0 AND risk_score <= 100);

ALTER TABLE risk_scores ADD CONSTRAINT ck_risk_scores_window_end_after_start CHECK (window_end > window_start);

ALTER TABLE shifts DROP CONSTRAINT shifts_rider_id_fkey;

ALTER TABLE shifts ADD FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE shifts ADD CONSTRAINT ck_shifts_distance_non_negative CHECK (distance_km >= 0);

ALTER TABLE shifts ADD CONSTRAINT ck_shifts_end_after_start CHECK (end_time IS NULL OR end_time >= start_time);

ALTER TABLE shifts ADD CONSTRAINT ck_shifts_premium_non_negative CHECK (premium_amount >= 0);

CREATE INDEX idx_telemetry_batches_shift_start_timestamp ON telemetry_batches (shift_id, start_timestamp);

ALTER TABLE telemetry_batches DROP CONSTRAINT telemetry_batches_shift_id_fkey;

ALTER TABLE telemetry_batches ADD FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE RESTRICT;

ALTER TABLE telemetry_batches ADD CONSTRAINT ck_telemetry_batches_end_after_start CHECK (end_timestamp >= start_timestamp);

ALTER TABLE telemetry_batches ADD CONSTRAINT ck_telemetry_batches_sample_count_positive CHECK (sample_count > 0);

ALTER TABLE telemetry_batches ADD CONSTRAINT ck_telemetry_batches_sequence_non_negative CHECK (batch_sequence >= 0);

ALTER TABLE telemetry_samples ADD CONSTRAINT ck_telemetry_samples_speed_non_negative CHECK (speed >= 0);

UPDATE alembic_version SET version_num='1c70384e9a27' WHERE alembic_version.version_num = '653c1f96e4dd';

-- Running upgrade 1c70384e9a27 -> 6b34e1bddbee

ALTER TABLE users ADD COLUMN wallet_balance FLOAT;

UPDATE users SET wallet_balance = 500.0;

ALTER TABLE users ALTER COLUMN wallet_balance SET NOT NULL;

UPDATE alembic_version SET version_num='6b34e1bddbee' WHERE alembic_version.version_num = '1c70384e9a27';

-- Running upgrade 6b34e1bddbee -> 7c45f2aef123

ALTER TABLE payments ADD COLUMN razorpay_order_id VARCHAR(100);

ALTER TABLE payments ADD COLUMN razorpay_signature VARCHAR(255);

CREATE INDEX ix_payments_razorpay_order_id ON payments (razorpay_order_id);

UPDATE alembic_version SET version_num='7c45f2aef123' WHERE alembic_version.version_num = '6b34e1bddbee';

-- Running upgrade 7c45f2aef123 -> e21bac4648a0

CREATE TABLE shift_behaviour_summaries (
    id UUID NOT NULL, 
    shift_id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    duration_seconds INTEGER NOT NULL, 
    distance_km NUMERIC(8, 2) NOT NULL, 
    sample_count INTEGER NOT NULL, 
    average_speed FLOAT NOT NULL, 
    max_speed FLOAT NOT NULL, 
    hard_braking_count INTEGER NOT NULL, 
    hard_acceleration_count INTEGER NOT NULL, 
    overspeeding_count INTEGER NOT NULL, 
    sharp_turn_count INTEGER NOT NULL, 
    hard_braking_rate FLOAT NOT NULL, 
    hard_acceleration_rate FLOAT NOT NULL, 
    overspeeding_rate FLOAT NOT NULL, 
    sharp_turn_rate FLOAT NOT NULL, 
    max_g NUMERIC(5, 2) NOT NULL, 
    accel_std FLOAT NOT NULL, 
    jerk_mean FLOAT NOT NULL, 
    sampling_density FLOAT NOT NULL, 
    data_quality_score NUMERIC(3, 2) NOT NULL, 
    is_valid BOOLEAN NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT ck_shift_behaviour_summaries_quality_score_range CHECK (data_quality_score >= 0 AND data_quality_score <= 1), 
    CONSTRAINT ck_shift_behaviour_summaries_distance_non_negative CHECK (distance_km >= 0), 
    CONSTRAINT ck_shift_behaviour_summaries_duration_non_negative CHECK (duration_seconds >= 0), 
    CONSTRAINT ck_shift_behaviour_summaries_sample_count_non_negative CHECK (sample_count >= 0), 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE RESTRICT
);

CREATE INDEX ix_shift_behaviour_summaries_rider_id ON shift_behaviour_summaries (rider_id);

CREATE UNIQUE INDEX ix_shift_behaviour_summaries_shift_id ON shift_behaviour_summaries (shift_id);

UPDATE alembic_version SET version_num='e21bac4648a0' WHERE alembic_version.version_num = '7c45f2aef123';

-- Running upgrade e21bac4648a0 -> decb4ac175f7

CREATE TABLE rider_behaviour_profiles (
    id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    computed_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    based_on_shift_count INTEGER NOT NULL, 
    based_on_valid_shift_count INTEGER NOT NULL, 
    recent_avg_speed FLOAT NOT NULL, 
    recent_max_speed FLOAT NOT NULL, 
    recent_hard_braking_rate FLOAT NOT NULL, 
    recent_hard_acceleration_rate FLOAT NOT NULL, 
    recent_overspeeding_rate FLOAT NOT NULL, 
    recent_sharp_turn_rate FLOAT NOT NULL, 
    recent_max_g NUMERIC(5, 2) NOT NULL, 
    recent_data_quality NUMERIC(3, 2) NOT NULL, 
    medium_avg_speed FLOAT NOT NULL, 
    medium_max_speed FLOAT NOT NULL, 
    medium_hard_braking_rate FLOAT NOT NULL, 
    medium_hard_acceleration_rate FLOAT NOT NULL, 
    medium_overspeeding_rate FLOAT NOT NULL, 
    medium_sharp_turn_rate FLOAT NOT NULL, 
    medium_max_g NUMERIC(5, 2) NOT NULL, 
    medium_data_quality NUMERIC(3, 2) NOT NULL, 
    long_term_avg_speed FLOAT NOT NULL, 
    long_term_max_speed FLOAT NOT NULL, 
    long_term_hard_braking_rate FLOAT NOT NULL, 
    long_term_hard_acceleration_rate FLOAT NOT NULL, 
    long_term_overspeeding_rate FLOAT NOT NULL, 
    long_term_sharp_turn_rate FLOAT NOT NULL, 
    long_term_max_g NUMERIC(5, 2) NOT NULL, 
    long_term_data_quality NUMERIC(3, 2) NOT NULL, 
    hard_braking_rate_variance FLOAT NOT NULL, 
    overspeeding_rate_variance FLOAT NOT NULL, 
    speed_variability FLOAT NOT NULL, 
    behaviour_consistency_score NUMERIC(5, 2) NOT NULL, 
    overall_behaviour_score NUMERIC(5, 2) NOT NULL, 
    data_quality_score NUMERIC(3, 2) NOT NULL, 
    confidence NUMERIC(3, 2) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT ck_rider_behaviour_profiles_shift_count_non_negative CHECK (based_on_shift_count >= 0), 
    CONSTRAINT ck_rider_behaviour_profiles_valid_le_total CHECK (based_on_valid_shift_count <= based_on_shift_count), 
    CONSTRAINT ck_rider_behaviour_profiles_valid_shift_count_non_negative CHECK (based_on_valid_shift_count >= 0), 
    CONSTRAINT ck_rider_behaviour_profiles_consistency_score_range CHECK (behaviour_consistency_score >= 0 AND behaviour_consistency_score <= 100), 
    CONSTRAINT ck_rider_behaviour_profiles_confidence_range CHECK (confidence >= 0 AND confidence <= 1), 
    CONSTRAINT ck_rider_behaviour_profiles_data_quality_range CHECK (data_quality_score >= 0 AND data_quality_score <= 1), 
    CONSTRAINT ck_rider_behaviour_profiles_overall_score_range CHECK (overall_behaviour_score >= 0 AND overall_behaviour_score <= 100), 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX ix_rider_behaviour_profiles_rider_id ON rider_behaviour_profiles (rider_id);

UPDATE alembic_version SET version_num='decb4ac175f7' WHERE alembic_version.version_num = 'e21bac4648a0';

-- Running upgrade decb4ac175f7 -> 3f6ad275c1e6

CREATE TABLE premium_quotes (
    id UUID NOT NULL, 
    shift_id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    is_cold_start BOOLEAN NOT NULL, 
    risk_score NUMERIC(5, 2), 
    risk_band VARCHAR(20), 
    confidence NUMERIC(3, 2) NOT NULL, 
    scoring_method VARCHAR(50) NOT NULL, 
    model_version VARCHAR(100) NOT NULL, 
    pricing_mode VARCHAR(30) NOT NULL, 
    base_premium NUMERIC(10, 2) NOT NULL, 
    previous_premium NUMERIC(10, 2) NOT NULL, 
    adjustment_amount NUMERIC(10, 2) NOT NULL, 
    final_premium NUMERIC(10, 2) NOT NULL, 
    rate_of_change_capped BOOLEAN NOT NULL, 
    explanation TEXT NOT NULL, 
    computed_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT ck_premium_quotes_base_premium_non_negative CHECK (base_premium >= 0), 
    CONSTRAINT ck_premium_quotes_confidence_range CHECK (confidence >= 0 AND confidence <= 1), 
    CONSTRAINT ck_premium_quotes_final_premium_non_negative CHECK (final_premium >= 0), 
    CONSTRAINT ck_premium_quotes_risk_score_range CHECK (risk_score IS NULL OR (risk_score >= 0 AND risk_score <= 100)), 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE RESTRICT
);

CREATE INDEX ix_premium_quotes_rider_id ON premium_quotes (rider_id);

CREATE UNIQUE INDEX ix_premium_quotes_shift_id ON premium_quotes (shift_id);

UPDATE alembic_version SET version_num='3f6ad275c1e6' WHERE alembic_version.version_num = 'decb4ac175f7';

-- Running upgrade 3f6ad275c1e6 -> bd7ba87c5821

CREATE TABLE helmet_verifications (
    id UUID NOT NULL, 
    rider_id UUID NOT NULL, 
    shift_id UUID, 
    predicted_class VARCHAR(30) NOT NULL, 
    confidence NUMERIC(5, 4) NOT NULL, 
    helmet_worn BOOLEAN NOT NULL, 
    model_version VARCHAR(100) NOT NULL, 
    consumed_at TIMESTAMP WITH TIME ZONE, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    CONSTRAINT ck_helmet_verifications_confidence_range CHECK (confidence >= 0 AND confidence <= 1), 
    FOREIGN KEY(rider_id) REFERENCES users (id) ON DELETE RESTRICT, 
    FOREIGN KEY(shift_id) REFERENCES shifts (id) ON DELETE SET NULL
);

CREATE INDEX ix_helmet_verifications_created_at ON helmet_verifications (created_at);

CREATE INDEX ix_helmet_verifications_rider_id ON helmet_verifications (rider_id);

CREATE INDEX ix_helmet_verifications_shift_id ON helmet_verifications (shift_id);

UPDATE alembic_version SET version_num='bd7ba87c5821' WHERE alembic_version.version_num = '3f6ad275c1e6';

-- Running upgrade 7c45f2aef123 -> 898d5c82409e

CREATE TABLE hospitals (
    id UUID NOT NULL, 
    name VARCHAR(255) NOT NULL, 
    locality VARCHAR(100) NOT NULL, 
    contact_number VARCHAR(30) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id)
);

CREATE INDEX ix_hospitals_locality ON hospitals (locality);

CREATE TABLE claim_medical_reports (
    id UUID NOT NULL, 
    claim_id UUID NOT NULL, 
    hospital_id UUID NOT NULL, 
    uploaded_by UUID NOT NULL, 
    file_reference VARCHAR(255) NOT NULL, 
    document_type VARCHAR(100) NOT NULL, 
    notes TEXT, 
    uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    PRIMARY KEY (id), 
    FOREIGN KEY(claim_id) REFERENCES claims (id) ON DELETE CASCADE, 
    FOREIGN KEY(hospital_id) REFERENCES hospitals (id) ON DELETE RESTRICT, 
    FOREIGN KEY(uploaded_by) REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX ix_claim_medical_reports_claim_id ON claim_medical_reports (claim_id);

CREATE INDEX ix_claim_medical_reports_hospital_id ON claim_medical_reports (hospital_id);

DROP INDEX ix_shift_behaviour_summaries_rider_id;

DROP INDEX ix_shift_behaviour_summaries_shift_id;

DROP TABLE shift_behaviour_summaries;

DROP INDEX ix_premium_quotes_rider_id;

DROP INDEX ix_premium_quotes_shift_id;

DROP TABLE premium_quotes;

DROP INDEX ix_rider_behaviour_profiles_rider_id;

DROP TABLE rider_behaviour_profiles;

ALTER TABLE incidents ADD COLUMN locality VARCHAR(100) DEFAULT 'Unknown' NOT NULL;

CREATE INDEX ix_incidents_locality ON incidents (locality);

ALTER TABLE users ADD COLUMN hospital_id UUID;

CREATE INDEX ix_users_hospital_id ON users (hospital_id);

ALTER TABLE users ADD FOREIGN KEY(hospital_id) REFERENCES hospitals (id) ON DELETE SET NULL;

INSERT INTO alembic_version (version_num) VALUES ('898d5c82409e') RETURNING alembic_version.version_num;

-- Running upgrade 898d5c82409e, bd7ba87c5821 -> 2b37be4dc170

DELETE FROM alembic_version WHERE alembic_version.version_num = '898d5c82409e';

UPDATE alembic_version SET version_num='2b37be4dc170' WHERE alembic_version.version_num = 'bd7ba87c5821';

-- Running upgrade 2b37be4dc170 -> 3f6b24ce83e2

ALTER TABLE incidents ADD COLUMN client_incident_id VARCHAR(64);

CREATE INDEX ix_incidents_client_incident_id ON incidents (client_incident_id);

UPDATE alembic_version SET version_num='3f6b24ce83e2' WHERE alembic_version.version_num = '2b37be4dc170';

-- Running upgrade 3f6b24ce83e2 -> 001216e07add

DROP INDEX ix_incidents_client_incident_id;

CREATE UNIQUE INDEX ix_incidents_client_incident_id ON incidents (client_incident_id);

UPDATE alembic_version SET version_num='001216e07add' WHERE alembic_version.version_num = '3f6b24ce83e2';

-- Running upgrade 001216e07add -> a6c093905017

ALTER TABLE incidents ADD COLUMN window_quality VARCHAR(20);

ALTER TABLE incidents ADD COLUMN decision_confidence VARCHAR(20);

ALTER TABLE incidents ADD COLUMN decision_evidence VARCHAR(500);

UPDATE alembic_version SET version_num='a6c093905017' WHERE alembic_version.version_num = '001216e07add';

-- Running upgrade a6c093905017 -> 35d5e86f8fbd

ALTER TABLE hospitals ADD COLUMN IF NOT EXISTS latitude FLOAT;

ALTER TABLE hospitals ADD COLUMN IF NOT EXISTS longitude FLOAT;

ALTER TABLE hospitals ALTER COLUMN locality TYPE VARCHAR(500);

ALTER TYPE payment_type_enum ADD VALUE IF NOT EXISTS 'WALLET_RECHARGE';

ALTER TABLE payments DROP CONSTRAINT IF EXISTS ck_payments_type_linkage;

UPDATE alembic_version SET version_num='35d5e86f8fbd' WHERE alembic_version.version_num = 'a6c093905017';

-- Running upgrade 35d5e86f8fbd -> 7a1c9e4f2b3d

UPDATE alembic_version SET version_num='7a1c9e4f2b3d' WHERE alembic_version.version_num = '35d5e86f8fbd';

-- Running upgrade 35d5e86f8fbd -> 4a2417d99f42

ALTER TABLE claim_medical_reports ADD COLUMN IF NOT EXISTS original_filename VARCHAR(255);;

ALTER TABLE claim_medical_reports ADD COLUMN IF NOT EXISTS mime_type VARCHAR(100);;

ALTER TABLE claim_medical_reports ADD COLUMN IF NOT EXISTS file_size INTEGER;;

INSERT INTO alembic_version (version_num) VALUES ('4a2417d99f42') RETURNING alembic_version.version_num;

-- Running upgrade 4a2417d99f42 -> 66f48f664e78

ALTER TABLE claims ADD COLUMN decided_by UUID;

ALTER TABLE claims ADD COLUMN decided_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE claims ADD COLUMN verification_run_id UUID;

ALTER TABLE claims ADD FOREIGN KEY(decided_by) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE claims ADD FOREIGN KEY(verification_run_id) REFERENCES audit_events (id) ON DELETE RESTRICT;

UPDATE alembic_version SET version_num='66f48f664e78' WHERE alembic_version.version_num = '4a2417d99f42';

-- Running upgrade 66f48f664e78 -> 76fc1d3732e4

ALTER TABLE claim_medical_reports ADD COLUMN patient_identifier VARCHAR(255);

ALTER TABLE claim_medical_reports ADD COLUMN facility_name VARCHAR(255);

ALTER TABLE claim_medical_reports ADD COLUMN hospital_locality VARCHAR(100);

ALTER TABLE claim_medical_reports ADD COLUMN admittance_timestamp TIMESTAMP WITH TIME ZONE;

ALTER TABLE claim_medical_reports ADD COLUMN diagnosis_notes TEXT;

UPDATE alembic_version SET version_num='76fc1d3732e4' WHERE alembic_version.version_num = '66f48f664e78';

-- Running upgrade 76fc1d3732e4, 7a1c9e4f2b3d -> 394da2cfd515

DELETE FROM alembic_version WHERE alembic_version.version_num = '76fc1d3732e4';

UPDATE alembic_version SET version_num='394da2cfd515' WHERE alembic_version.version_num = '7a1c9e4f2b3d';

COMMIT;

