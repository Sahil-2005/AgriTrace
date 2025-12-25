-- Add crop analysis columns to batches table
-- Run this SQL in your Supabase dashboard SQL editor

-- Add columns for storing crop health and soil analysis data
ALTER TABLE batches ADD COLUMN IF NOT EXISTS crop_analysis JSONB;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS disease_data JSONB;
ALTER TABLE batches ADD COLUMN IF NOT EXISTS soil_data JSONB;

-- Add comment to explain the columns
COMMENT ON COLUMN batches.crop_analysis IS 'Comprehensive analysis from Gemini AI combining crop health and soil data';
COMMENT ON COLUMN batches.disease_data IS 'Disease prediction data from disease predictor API';
COMMENT ON COLUMN batches.soil_data IS 'Soil data from IoT hardware device';

