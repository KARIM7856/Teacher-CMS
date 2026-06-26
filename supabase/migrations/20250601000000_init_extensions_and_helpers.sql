-- 20250601000000_init_extensions_and_helpers.sql
-- Extensions, enum types, and table-independent helper functions.
-- This must run before the core schema (which uses these types/functions).

-- ── Extensions (Supabase keeps these in the "extensions" schema) ──────────────
create extension if not exists pgcrypto with schema extensions;  -- crypt(), gen_salt()
create extension if not exists pg_trgm  with schema extensions;  -- trigram search
create extension if not exists unaccent with schema extensions;  -- diacritic folding
-- gen_random_uuid() is built into Postgres 13+ (no extension needed).

-- ── Enum types ────────────────────────────────────────────────────────────────
do $$ begin
  create type public.user_role as enum ('student', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.media_type as enum ('video', 'pdf', 'other');
exception when duplicate_object then null; end $$;

-- ── Arabic text normalization (search/sort helper) ────────────────────────────
-- Folds an Arabic string to a canonical form so search matches regardless of how
-- the text was typed:
--   * lowercases any embedded Latin characters
--   * unifies alef / hamza / yaa / taa-marbuta variants (alef forms->ا, ى ئ->ي, ؤ->و, ة->ه)
--   * strips tashkil (harakat, U+064B-U+065F, U+0670) and the tatweel mark (U+0640)
-- Marked IMMUTABLE so it can back a STORED generated column and a GIN index.
create or replace function public.normalize_arabic(input text)
returns text
language sql
immutable
as $$
  select case
    when input is null then null
    else regexp_replace(
           translate(lower(input), 'أإآٱىئؤةـ', 'ااااييوه'),
           E'[ً-ٰٟـ]', '', 'g'
         )
  end;
$$;

comment on function public.normalize_arabic(text)
  is 'Canonical Arabic form for search: folds alef/hamza/yaa/taa variants and strips diacritics.';

-- ── Generic updated_at bump trigger ───────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
