-- Add missing interests column to public.profiles and permit avatar/document updates
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS interests text[] NOT NULL DEFAULT '{}';

-- Allow update operations on storage.objects for documents bucket
DROP POLICY IF EXISTS "documents_update_anon" ON storage.objects;
CREATE POLICY "documents_update_anon" ON storage.objects
FOR UPDATE TO anon, authenticated
USING (bucket_id = 'documents');
