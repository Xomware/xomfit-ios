-- ============================================================
-- Workout Marketplace Migration
-- Created: 2026-02-28
-- ============================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- full-text search on title

-- ============================================================
-- workout_programs table
-- ============================================================

CREATE TABLE IF NOT EXISTS workout_programs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title               TEXT NOT NULL,
    description         TEXT NOT NULL DEFAULT '',
    creator_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    creator_name        TEXT NOT NULL DEFAULT '',
    creator_avatar_url  TEXT,
    days_per_week       INT NOT NULL DEFAULT 3 CHECK (days_per_week BETWEEN 1 AND 7),
    duration_weeks      INT NOT NULL DEFAULT 4 CHECK (duration_weeks BETWEEN 1 AND 52),
    difficulty          TEXT NOT NULL DEFAULT 'intermediate'
                            CHECK (difficulty IN ('beginner','intermediate','advanced','elite')),
    goals               TEXT[] NOT NULL DEFAULT '{}',
    exercises           JSONB NOT NULL DEFAULT '[]',
    price               NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (price >= 0),
    rating              NUMERIC(3,2) NOT NULL DEFAULT 0.00 CHECK (rating BETWEEN 0 AND 5),
    review_count        INT NOT NULL DEFAULT 0,
    import_count        INT NOT NULL DEFAULT 0,
    is_featured         BOOLEAN NOT NULL DEFAULT FALSE,
    is_public           BOOLEAN NOT NULL DEFAULT TRUE,
    tags                TEXT[] NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast filtering / sorting
CREATE INDEX IF NOT EXISTS idx_programs_public       ON workout_programs (is_public);
CREATE INDEX IF NOT EXISTS idx_programs_featured     ON workout_programs (is_featured) WHERE is_featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_programs_creator      ON workout_programs (creator_id);
CREATE INDEX IF NOT EXISTS idx_programs_rating       ON workout_programs (rating DESC);
CREATE INDEX IF NOT EXISTS idx_programs_import_count ON workout_programs (import_count DESC);
CREATE INDEX IF NOT EXISTS idx_programs_created_at   ON workout_programs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_programs_difficulty   ON workout_programs (difficulty);
CREATE INDEX IF NOT EXISTS idx_programs_title_trgm   ON workout_programs USING GIN (title gin_trgm_ops);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_programs_updated_at ON workout_programs;
CREATE TRIGGER trg_programs_updated_at
    BEFORE UPDATE ON workout_programs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Sync creator_name from auth.users on insert
CREATE OR REPLACE FUNCTION sync_program_creator_name()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    SELECT COALESCE(raw_user_meta_data->>'full_name', email)
    INTO NEW.creator_name
    FROM auth.users
    WHERE id = NEW.creator_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_programs_creator_name ON workout_programs;
CREATE TRIGGER trg_programs_creator_name
    BEFORE INSERT ON workout_programs
    FOR EACH ROW EXECUTE FUNCTION sync_program_creator_name();

-- ============================================================
-- program_reviews table
-- ============================================================

CREATE TABLE IF NOT EXISTS program_reviews (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id      UUID NOT NULL REFERENCES workout_programs(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name       TEXT NOT NULL DEFAULT '',
    user_avatar_url TEXT,
    rating          INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    body            TEXT NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (program_id, user_id)   -- One review per user per program
);

CREATE INDEX IF NOT EXISTS idx_reviews_program    ON program_reviews (program_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user       ON program_reviews (user_id);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON program_reviews (created_at DESC);

-- Sync reviewer name on insert
CREATE OR REPLACE FUNCTION sync_review_user_name()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    SELECT COALESCE(raw_user_meta_data->>'full_name', email)
    INTO NEW.user_name
    FROM auth.users
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_user_name ON program_reviews;
CREATE TRIGGER trg_reviews_user_name
    BEFORE INSERT ON program_reviews
    FOR EACH ROW EXECUTE FUNCTION sync_review_user_name();

-- Recompute program average rating after each review insert/update/delete
CREATE OR REPLACE FUNCTION refresh_program_rating()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_program_id UUID;
BEGIN
    v_program_id := COALESCE(NEW.program_id, OLD.program_id);
    UPDATE workout_programs
    SET
        rating       = COALESCE((SELECT AVG(rating) FROM program_reviews WHERE program_id = v_program_id), 0),
        review_count = (SELECT COUNT(*) FROM program_reviews WHERE program_id = v_program_id)
    WHERE id = v_program_id;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_refresh_rating ON program_reviews;
CREATE TRIGGER trg_refresh_rating
    AFTER INSERT OR UPDATE OR DELETE ON program_reviews
    FOR EACH ROW EXECUTE FUNCTION refresh_program_rating();

-- ============================================================
-- user_program_imports table
-- ============================================================

CREATE TABLE IF NOT EXISTS user_program_imports (
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    program_id  UUID NOT NULL REFERENCES workout_programs(id) ON DELETE CASCADE,
    imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, program_id)
);

CREATE INDEX IF NOT EXISTS idx_imports_user    ON user_program_imports (user_id);
CREATE INDEX IF NOT EXISTS idx_imports_program ON user_program_imports (program_id);

-- ============================================================
-- RPC: increment_import_count
-- ============================================================

CREATE OR REPLACE FUNCTION increment_import_count(p_program_id UUID)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE workout_programs
    SET import_count = import_count + 1
    WHERE id = p_program_id;
END;
$$;

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE workout_programs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE program_reviews   ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_program_imports ENABLE ROW LEVEL SECURITY;

-- workout_programs
DROP POLICY IF EXISTS "Public programs are viewable by all"   ON workout_programs;
DROP POLICY IF EXISTS "Owners can manage their programs"      ON workout_programs;

CREATE POLICY "Public programs are viewable by all" ON workout_programs
    FOR SELECT USING (is_public = TRUE OR creator_id = auth.uid());

CREATE POLICY "Owners can manage their programs" ON workout_programs
    FOR ALL USING (creator_id = auth.uid());

-- program_reviews
DROP POLICY IF EXISTS "Reviews are public"           ON program_reviews;
DROP POLICY IF EXISTS "Users can manage own reviews" ON program_reviews;

CREATE POLICY "Reviews are public" ON program_reviews
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can manage own reviews" ON program_reviews
    FOR ALL USING (user_id = auth.uid());

-- user_program_imports
DROP POLICY IF EXISTS "Users see own imports" ON user_program_imports;
CREATE POLICY "Users see own imports" ON user_program_imports
    FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- Seed: sample featured programs (safe to re-run)
-- ============================================================

INSERT INTO workout_programs (
    id, title, description, creator_id, creator_name,
    days_per_week, duration_weeks, difficulty, goals,
    price, is_featured, is_public, tags, rating, review_count, import_count
)
SELECT
    gen_random_uuid(),
    '5/3/1 Powerbuilding',
    'Jim Wendler''s legendary 5/3/1 program adapted for muscle mass and strength. 4-day upper/lower split.',
    (SELECT id FROM auth.users LIMIT 1),
    'XomFit Team',
    4, 12, 'intermediate', ARRAY['strength','hypertrophy'],
    0, TRUE, TRUE, ARRAY['powerlifting','4-day','barbells'],
    4.8, 0, 0
WHERE EXISTS (SELECT 1 FROM auth.users LIMIT 1)
ON CONFLICT DO NOTHING;
