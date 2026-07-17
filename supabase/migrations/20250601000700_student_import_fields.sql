-- 20250601000700_student_import_fields.sql
-- Roster fields for bulk student import from the teacher's Excel sheets.
--
-- The admin portal can import a workbook (one sheet per class) and create the
-- student accounts in bulk. Two identifying fields from that sheet are worth
-- keeping on the profile so an app account can later be reconciled with the
-- teacher's own roster:
--   • serial_number — الرقم التسلسلي (the student's serial in the class list)
--   • request_code  — كود الطلب     (the per-student request/enrolment code)
-- Both are free-form text (they may carry leading zeros or non-numeric forms),
-- nullable (pre-existing and manually-created students won't have them), and
-- admin-facing only — the student app never reads them.
-- Depends on: 20250601000100 (profiles table).

alter table public.profiles
  add column if not exists serial_number text,
  add column if not exists request_code  text;

comment on column public.profiles.serial_number is
  'الرقم التسلسلي from the teacher''s class sheet (bulk import). Free-form text.';
comment on column public.profiles.request_code is
  'كود الطلب from the teacher''s class sheet (bulk import). Free-form text.';

-- No RLS change needed: profiles policies already let admins read/write every
-- column and let a student read only their own row. These columns inherit that.
