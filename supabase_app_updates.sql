-- =================================================================
-- Migration: Create app_updates Table and app_releases Storage Bucket
-- =================================================================

-- 1. Create table for tracking published OTA updates
CREATE TABLE IF NOT EXISTS public.app_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_name TEXT NOT NULL,
    version_code INTEGER NOT NULL UNIQUE,
    apk_url TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    release_notes TEXT NOT NULL DEFAULT '',
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index on version_code for fast lookup of newest release
CREATE INDEX IF NOT EXISTS idx_app_updates_version_code ON public.app_updates (version_code DESC);

-- Enable RLS
ALTER TABLE public.app_updates ENABLE ROW LEVEL SECURITY;

-- Allow public read access to app_updates so any app client can check for updates
CREATE POLICY "Public read app_updates" ON public.app_updates
    FOR SELECT
    USING (true);

-- Allow authenticated admins or anon key to insert new releases
CREATE POLICY "Allow update insert" ON public.app_updates
    FOR INSERT
    WITH CHECK (true);

-- Enable Realtime for instant broadcast to connected clients
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_updates;

-- 2. Create Storage Bucket for APKs
INSERT INTO storage.buckets (id, name, public)
VALUES ('app_releases', 'app_releases', true)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: Public Read & Download for APK files
CREATE POLICY "Public read app_releases bucket" ON storage.objects
    FOR SELECT
    USING (bucket_id = 'app_releases');

-- Storage RLS: Insert/Upload
CREATE POLICY "Allow upload to app_releases bucket" ON storage.objects
    FOR INSERT
    WITH CHECK (bucket_id = 'app_releases');
