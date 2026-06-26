# /admin — Web admin portal

The **teacher-facing** tool. A web app the teacher uses to create and publish
content for students.

## Purpose

- Create, edit, and publish posts (embedded video, PDFs, other files).
- Organize content by main category → subcategory and apply freeform tags.
- Build and order playlists.
- Manage uploaded files in Supabase Storage.

## Language & direction

**Arabic-first and RTL by default** (`<html lang="ar" dir="rtl">`). Use CSS
logical properties (`margin-inline-*`, `padding-inline-*`, `text-align: start`)
rather than `left` / `right`, bundle an Arabic font, and externalize all
user-facing strings. See `/CLAUDE.md` → *Language & direction*.

## Stack

A Node-based web app. The specific framework will be chosen in a later phase.

## Backend

Talks to the shared Supabase project (see `/supabase`) for auth, data, and file
storage.

## Status

Not scaffolded yet. The web project will be created in a later phase.
