-- Migration: Setup Supabase Storage Bucket for Avatars

-- 1. Buat bucket 'avatars' (public = true agar foto bisa diakses via URL publik)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars', 
    'avatars', 
    true, 
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Kebijakan RLS untuk storage.objects
-- Izinkan siapa saja membaca/melihat avatar (Public Read)
DROP POLICY IF EXISTS "Avatar Public Access" ON storage.objects;
CREATE POLICY "Avatar Public Access"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

-- Izinkan user yang login (authenticated) untuk mengunggah avatar
DROP POLICY IF EXISTS "Authenticated User Upload Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Upload Avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars');

-- Izinkan user yang login (authenticated) untuk memperbarui avatar
DROP POLICY IF EXISTS "Authenticated User Update Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Update Avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'avatars');

-- Izinkan user yang login (authenticated) untuk menghapus avatar
DROP POLICY IF EXISTS "Authenticated User Delete Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Delete Avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'avatars');
