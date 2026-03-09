-- Body Composition table
-- Tracks user weight, circumference measurements, body fat, and optional progress photos
-- Private by default; users can optionally share entries

CREATE TABLE IF NOT EXISTS body_composition (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Weight
    weight_lbs      NUMERIC(6, 2),
    
    -- Circumference measurements (inches)
    chest           NUMERIC(5, 2),
    waist           NUMERIC(5, 2),
    hips            NUMERIC(5, 2),
    bicep_left      NUMERIC(5, 2),
    bicep_right     NUMERIC(5, 2),
    thigh_left      NUMERIC(5, 2),
    thigh_right     NUMERIC(5, 2),
    calf            NUMERIC(5, 2),
    neck            NUMERIC(5, 2),
    shoulders       NUMERIC(5, 2),
    
    -- Body composition
    body_fat_percent NUMERIC(4, 2),
    
    -- Progress photo (stored in Supabase Storage bucket "progress-photos")
    photo_url       TEXT,
    
    -- Metadata
    notes           TEXT,
    is_private      BOOLEAN NOT NULL DEFAULT true,
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for user timeline queries
CREATE INDEX idx_body_composition_user_recorded
    ON body_composition(user_id, recorded_at DESC);

-- Row Level Security
ALTER TABLE body_composition ENABLE ROW LEVEL SECURITY;

-- Users can read their own entries
CREATE POLICY "Users can view own body composition"
    ON body_composition FOR SELECT
    USING (auth.uid()::text = user_id);

-- Users can read public entries of others (is_private = false)
CREATE POLICY "Users can view public body composition"
    ON body_composition FOR SELECT
    USING (is_private = false);

-- Users can insert their own entries
CREATE POLICY "Users can insert own body composition"
    ON body_composition FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);

-- Users can update their own entries
CREATE POLICY "Users can update own body composition"
    ON body_composition FOR UPDATE
    USING (auth.uid()::text = user_id);

-- Users can delete their own entries
CREATE POLICY "Users can delete own body composition"
    ON body_composition FOR DELETE
    USING (auth.uid()::text = user_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_body_composition_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER body_composition_updated_at
    BEFORE UPDATE ON body_composition
    FOR EACH ROW
    EXECUTE FUNCTION update_body_composition_updated_at();

-- Storage bucket for progress photos (run in Supabase dashboard or via CLI)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('progress-photos', 'progress-photos', false)
-- ON CONFLICT DO NOTHING;

-- Storage RLS: users can only upload/view their own photos (stored at {user_id}/{entry_id}.jpg)
-- CREATE POLICY "Users can upload own progress photos"
--     ON storage.objects FOR INSERT
--     WITH CHECK (bucket_id = 'progress-photos' AND (storage.foldername(name))[1] = auth.uid()::text);
--
-- CREATE POLICY "Users can view own progress photos"
--     ON storage.objects FOR SELECT
--     USING (bucket_id = 'progress-photos' AND (storage.foldername(name))[1] = auth.uid()::text);
