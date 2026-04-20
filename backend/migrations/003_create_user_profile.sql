-- BMI Health Tracker Database Migration
-- Version: 003
-- Description: Create user_profile singleton table for form pre-fill
-- Date: 2026-04-20

CREATE TABLE IF NOT EXISTS user_profile (
  id INTEGER PRIMARY KEY DEFAULT 1,
  name VARCHAR(100),
  height_cm NUMERIC(5,2) NOT NULL CHECK (height_cm > 0 AND height_cm < 300),
  age INTEGER NOT NULL CHECK (age > 0 AND age < 150),
  sex VARCHAR(10) NOT NULL CHECK (sex IN ('male', 'female')),
  activity_level VARCHAR(30) NOT NULL CHECK (activity_level IN ('sedentary', 'light', 'moderate', 'active', 'very_active')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT singleton CHECK (id = 1)
);

COMMENT ON TABLE user_profile IS 'Singleton table storing the user profile used to pre-fill the measurement form';
COMMENT ON COLUMN user_profile.id IS 'Always 1 — enforces singleton via CHECK constraint';
COMMENT ON COLUMN user_profile.height_cm IS 'Height in centimeters';
COMMENT ON COLUMN user_profile.age IS 'Age in years';
COMMENT ON COLUMN user_profile.sex IS 'Biological sex (male/female)';
COMMENT ON COLUMN user_profile.activity_level IS 'Physical activity level';

SELECT 'Migration 003 completed successfully - user_profile table created' AS status;
