CREATE TABLE meal_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  food_name text NOT NULL,
  calories integer NOT NULL,
  protein_g real,
  carbs_g real,
  fat_g real,
  servings real DEFAULT 1.0,
  meal_type text CHECK (meal_type IN ('breakfast','lunch','dinner','snack')),
  logged_at timestamptz DEFAULT now()
);

-- RLS policies
ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own meal logs"
  ON meal_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own meal logs"
  ON meal_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own meal logs"
  ON meal_logs FOR DELETE
  USING (auth.uid() = user_id);

-- Index for efficient daily queries
CREATE INDEX idx_meal_logs_user_date ON meal_logs (user_id, logged_at DESC);
