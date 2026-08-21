-- Add notifications_cleared_at timestamp to profiles table to persist clear-all state across devices/installs
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS notifications_cleared_at TIMESTAMPTZ DEFAULT now();
