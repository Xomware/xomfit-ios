-- Create storage bucket for workout photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'workout-photos',
    'workout-photos',
    true,
    5242880,  -- 5MB max per file
    ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- RLS: authenticated users can upload to their own folder
CREATE POLICY "Users can upload own workout photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'workout-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- RLS: anyone can view workout photos (public bucket)
CREATE POLICY "Public read access for workout photos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'workout-photos');

-- RLS: users can delete their own photos
CREATE POLICY "Users can delete own workout photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'workout-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- RLS: users can update (upsert) their own photos
CREATE POLICY "Users can update own workout photos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'workout-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
