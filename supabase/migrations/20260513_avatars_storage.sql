-- Create storage bucket for profile avatars
-- Path convention: avatars/{userId}/{uuid}.jpg
-- See PhotoService.uploadAvatar(...) on iOS for the exact upload contract.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    2097152,  -- 2MB max per file (avatars are heavily compressed client-side to ~500KB)
    ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- RLS: authenticated users can upload to their own folder
CREATE POLICY "Users can upload own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- RLS: anyone can read avatars (public bucket — they're shown in feeds, profiles, etc.)
CREATE POLICY "Public read access for avatars"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'avatars');

-- RLS: users can update (upsert) their own avatar
CREATE POLICY "Users can update own avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- RLS: users can delete their own avatar files (housekeeping when replacing)
CREATE POLICY "Users can delete own avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
