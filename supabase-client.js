import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const supabaseUrl = 'https://clynmrixrnjuanbbibgc.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNseW5tcml4cm5qdWFuYmJpYmdjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ5MjA3MDYsImV4cCI6MjEwMDQ5NjcwNn0.5pBy6UU_NLetfUJhocZcqxUTMma0FH6hIerVOajhAoQ';

export const supabase = createClient(supabaseUrl, supabaseKey);
