-- XomFit Challenges Schema
-- Run these migrations in your Supabase project to set up the challenges feature

-- Challenges Table
CREATE TABLE challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'upcoming',
    created_by UUID NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT valid_status CHECK (status IN ('upcoming', 'active', 'completed', 'cancelled')),
    CONSTRAINT valid_type CHECK (type IN ('most_volume', 'heaviest_bench', 'most_workouts', 'fastest_mile', 'strength_gain'))
);

-- Challenge Participants (Junction Table)
CREATE TABLE challenge_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(challenge_id, user_id)
);

-- Challenge Results Table
CREATE TABLE challenge_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    rank INTEGER NOT NULL DEFAULT 0,
    value DECIMAL(10, 2) NOT NULL,
    unit TEXT NOT NULL,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(challenge_id, user_id)
);

-- Streaks Table
CREATE TABLE streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    count INTEGER NOT NULL DEFAULT 0,
    last_workout_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, challenge_id)
);

-- Badges Table
CREATE TABLE badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    earned_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    challenge_id UUID REFERENCES challenges(id) ON DELETE SET NULL
);

-- Friendships Table
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id1 UUID NOT NULL,
    user_id2 UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id1, user_id2),
    CONSTRAINT no_self_friendship CHECK (user_id1 != user_id2)
);

-- Create Indexes for Performance
CREATE INDEX challenges_created_by_idx ON challenges(created_by);
CREATE INDEX challenges_status_idx ON challenges(status);
CREATE INDEX challenges_start_date_idx ON challenges(start_date);
CREATE INDEX challenges_end_date_idx ON challenges(end_date);

CREATE INDEX challenge_participants_challenge_idx ON challenge_participants(challenge_id);
CREATE INDEX challenge_participants_user_idx ON challenge_participants(user_id);

CREATE INDEX challenge_results_challenge_idx ON challenge_results(challenge_id);
CREATE INDEX challenge_results_user_idx ON challenge_results(user_id);
CREATE INDEX challenge_results_rank_idx ON challenge_results(rank);

CREATE INDEX streaks_user_idx ON streaks(user_id);
CREATE INDEX streaks_challenge_idx ON streaks(challenge_id);
CREATE INDEX streaks_last_workout_idx ON streaks(last_workout_date);

CREATE INDEX badges_user_idx ON badges(user_id);
CREATE INDEX badges_challenge_idx ON badges(challenge_id);
CREATE INDEX badges_earned_date_idx ON badges(earned_date);

CREATE INDEX friendships_user1_idx ON friendships(user_id1);
CREATE INDEX friendships_user2_idx ON friendships(user_id2);

-- Enable Row-Level Security (RLS)
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Challenges
CREATE POLICY "Challenges are viewable by participants" ON challenges
    FOR SELECT USING (
        id IN (
            SELECT challenge_id FROM challenge_participants WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create challenges" ON challenges
    FOR INSERT WITH CHECK (created_by = auth.uid());

-- RLS Policies for Challenge Participants
CREATE POLICY "Participants are viewable in their challenges" ON challenge_participants
    FOR SELECT USING (
        challenge_id IN (
            SELECT id FROM challenges WHERE created_by = auth.uid()
        ) OR user_id = auth.uid()
    );

-- RLS Policies for Challenge Results
CREATE POLICY "Results are viewable by participants" ON challenge_results
    FOR SELECT USING (
        challenge_id IN (
            SELECT challenge_id FROM challenge_participants WHERE user_id = auth.uid()
        )
    );

-- RLS Policies for Streaks
CREATE POLICY "Users can view their own streaks" ON streaks
    FOR SELECT USING (user_id = auth.uid());

-- RLS Policies for Badges
CREATE POLICY "Users can view their own badges" ON badges
    FOR SELECT USING (user_id = auth.uid());

-- RLS Policies for Friendships
CREATE POLICY "Users can view their friendships" ON friendships
    FOR SELECT USING (user_id1 = auth.uid() OR user_id2 = auth.uid());

-- View: Active Challenges with Participant Count
CREATE OR REPLACE VIEW active_challenges_with_stats AS
SELECT 
    c.id,
    c.type,
    c.status,
    c.created_by,
    c.start_date,
    c.end_date,
    COUNT(DISTINCT cp.user_id) as participant_count,
    MAX(cr.rank) as highest_rank
FROM challenges c
LEFT JOIN challenge_participants cp ON c.id = cp.challenge_id
LEFT JOIN challenge_results cr ON c.id = cr.challenge_id
WHERE c.status = 'active'
GROUP BY c.id, c.type, c.status, c.created_by, c.start_date, c.end_date;

-- View: User Leaderboards
CREATE OR REPLACE VIEW challenge_leaderboards AS
SELECT 
    c.id as challenge_id,
    c.type as challenge_type,
    cr.user_id,
    cr.rank,
    cr.value,
    cr.unit,
    s.count as streak_count,
    COUNT(b.id) as badge_count
FROM challenges c
JOIN challenge_results cr ON c.id = cr.challenge_id
LEFT JOIN streaks s ON c.id = s.challenge_id AND cr.user_id = s.user_id
LEFT JOIN badges b ON cr.user_id = b.user_id AND c.id = b.challenge_id
GROUP BY c.id, c.type, cr.user_id, cr.rank, cr.value, cr.unit, s.count;
