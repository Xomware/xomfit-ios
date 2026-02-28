-- Gyms table
CREATE TABLE IF NOT EXISTS gyms (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    address     TEXT,
    latitude    DOUBLE PRECISION NOT NULL,
    longitude   DOUBLE PRECISION NOT NULL,
    logo_url    TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Spatial index for nearby gym queries
CREATE INDEX idx_gyms_location ON gyms (latitude, longitude);

-- PostGIS function for nearby gyms (uses Haversine formula)
CREATE OR REPLACE FUNCTION nearby_gyms(lat FLOAT, lng FLOAT, radius_meters FLOAT)
RETURNS SETOF gyms
LANGUAGE sql STABLE AS $$
    SELECT *
    FROM gyms
    WHERE (
        6371000 * acos(
            cos(radians(lat)) * cos(radians(latitude))
            * cos(radians(longitude) - radians(lng))
            + sin(radians(lat)) * sin(radians(latitude))
        )
    ) <= radius_meters
    ORDER BY (
        6371000 * acos(
            cos(radians(lat)) * cos(radians(latitude))
            * cos(radians(longitude) - radians(lng))
            + sin(radians(lat)) * sin(radians(latitude))
        )
    );
$$;

-- Gym Check-ins table
CREATE TABLE IF NOT EXISTS gym_checkins (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             TEXT NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    gym_id              UUID NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
    gym_name            TEXT,           -- Denormalized for query convenience
    gym_address         TEXT,
    checked_in_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    checked_out_at      TIMESTAMPTZ,    -- NULL = currently active
    note                TEXT,
    is_public           BOOLEAN NOT NULL DEFAULT true,
    
    -- Denormalized display info (filled by trigger from profiles)
    user_display_name   TEXT,
    user_avatar_url     TEXT,
    user_username       TEXT,
    
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_gym_checkins_user         ON gym_checkins(user_id);
CREATE INDEX idx_gym_checkins_gym_active   ON gym_checkins(gym_id) WHERE checked_out_at IS NULL;
CREATE INDEX idx_gym_checkins_checked_in   ON gym_checkins(user_id, checked_in_at DESC);

-- Row Level Security
ALTER TABLE gym_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;

-- Gyms are readable by all authenticated users
CREATE POLICY "Gyms are publicly readable"
    ON gyms FOR SELECT
    TO authenticated
    USING (true);

-- Users can read their own check-ins
CREATE POLICY "Users can view own check-ins"
    ON gym_checkins FOR SELECT
    USING (auth.uid()::text = user_id);

-- Users can read public check-ins
CREATE POLICY "Users can view public check-ins"
    ON gym_checkins FOR SELECT
    USING (is_public = true);

-- Users can insert their own check-ins
CREATE POLICY "Users can insert own check-ins"
    ON gym_checkins FOR INSERT
    WITH CHECK (auth.uid()::text = user_id);

-- Users can update their own check-ins (e.g. check-out)
CREATE POLICY "Users can update own check-ins"
    ON gym_checkins FOR UPDATE
    USING (auth.uid()::text = user_id);

-- Seed some gyms (example data — replace with real gym data)
INSERT INTO gyms (name, address, latitude, longitude) VALUES
    ('Equinox Midtown', '1633 Broadway, New York, NY 10019', 40.7614, -73.9836),
    ('Planet Fitness - Times Square', '234 W 42nd St, New York, NY 10036', 40.7563, -73.9888),
    ('Crunch Fitness - Union Square', '90 E 16th St, New York, NY 10003', 40.7368, -73.9890),
    ('NYSC - Upper West Side', '2162 Broadway, New York, NY 10024', 40.7847, -73.9814),
    ('Barry''s Bootcamp - Flatiron', '29 W 20th St, New York, NY 10011', 40.7419, -73.9940)
ON CONFLICT DO NOTHING;
