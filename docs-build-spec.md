# Crumb Trail — Build Spec

## 1. Overview

**Crumb Trail** is a mobile app for sharing what you're eating. It's part social feed, part local food guide, part recipe sharing.

Users post a "crumb": a photo of a meal, the meal type (breakfast, lunch, dinner, or snack), a caption, the main ingredients, and optionally a recipe. If they're eating out, they tag the restaurant. Other users browse crumbs near them or search by ingredient or recipe item.

**Core rule: there are no comments.** The only text on a post is the poster's own caption. This is deliberate. It keeps the app positive and about inspiration, not arguments.

**Tagline:** "Follow the crumbs."

### Terminology used in the UI
- A post is a **crumb**. Posting is **"Drop a crumb."**
- A user's profile history is **"Your trail."**
- The local feed is **"Crumbs near you."**

---

## 2. Tech Stack

- **App:** React Native with Expo (managed workflow), TypeScript, Expo Router
- **Backend:** Supabase (Auth, Postgres, Storage, Edge Functions)
- **Location queries:** PostGIS extension in Supabase Postgres
- **Restaurant lookup:** Google Places API (New): Autocomplete + Place Details, called only from a Supabase Edge Function so the API key never ships in the app
- **Image moderation:** AWS Rekognition `DetectModerationLabels`, called from a Supabase Edge Function
- **Device location:** `expo-location`
- **Photos:** `expo-image-picker` + `expo-image-manipulator` (resize/compress)
- **Admin page:** a small web page (Next.js or plain React), admin-only, using the same Supabase project

### Environment variables
```
EXPO_PUBLIC_SUPABASE_URL=
EXPO_PUBLIC_SUPABASE_ANON_KEY=
# Edge Function secrets only (never in the app bundle):
GOOGLE_PLACES_API_KEY=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=
```

---

## 3. Features (v1)

### 3.1 Accounts
- Sign up / sign in with email (magic link or password) and Sign in with Apple. Apple requires Sign in with Apple if any other social login is offered.
- Profile: display name, username (unique), optional avatar, optional home city (text only).
- On first sign-up, the user must accept the Terms of Use, which state there is zero tolerance for objectionable content or abusive users. Apple requires this for apps with user-generated content. Store the acceptance timestamp.
- **In-app account deletion** (required by Apple): deletes the profile, all crumbs, and all stored photos.

### 3.2 Dropping a crumb (posting)
Fields:
- **Photo** (required, 1 photo)
- **Meal type** (required): `breakfast`, `lunch`, `dinner`, `snack`. Default the selection based on the device's local time of day, but let the user change it.
- **Caption** (optional, max 280 characters)
- **Main ingredients** (optional): tag-style input, up to 15 tags, each lowercase and trimmed
- **Recipe** (optional): free-text field, max 5,000 characters
- **Where:** a toggle with two options:
  - **Eating out** → search for and tag a restaurant (see 3.3). The crumb's location = the restaurant's location.
  - **Home / elsewhere** → use device location, **rounded for privacy** (see 3.5). The user can also choose "Don't show location," in which case the crumb does not appear in location-based results.

Photo handling:
- Resize to max 1600px on the long edge, compress to JPEG ~80% quality.
- **Strip all EXIF metadata before upload**, especially GPS data. Re-encoding through `expo-image-manipulator` does this; verify it.
- Upload to Supabase Storage bucket `crumb-photos` at path `{user_id}/{crumb_id}.jpg`.

After upload, the crumb is created with `status = 'pending'` and the moderation function runs (see 3.7). It becomes visible only when `status = 'visible'`.

### 3.3 Restaurant tagging
- User types a restaurant name. The app calls an Edge Function `places-autocomplete` with the text and the user's approximate location (for location bias).
- User picks a result. The app calls Edge Function `places-details`, which returns name, address, and lat/lng.
- Upsert into the `restaurants` table keyed by `google_place_id` so each restaurant is stored once.
- Use Places session tokens to keep Autocomplete billing low.

### 3.4 Browsing and search
**Home tab: "Crumbs near you"**
- Shows visible crumbs within a radius of the user's current location, newest first.
- Radius filter: 1, 5, 10, 25 miles (default 10).
- Meal type filter chips: All / Breakfast / Lunch / Dinner / Snack.
- Infinite scroll with cursor pagination (by `created_at`, `id`).
- If location permission is denied, let the user type a city or ZIP and geocode it (Edge Function using Google Geocoding) to use as the search center.

**Search tab**
- Search by ingredient or recipe text (e.g., "avocado," "chicken tortilla soup").
- Matches against ingredient tags and full-text search on caption + recipe.
- Same radius and meal type filters available, plus an "Anywhere" option.

**Restaurant page**
- Tapping a tagged restaurant shows its name, address, and all visible crumbs tagged there.

**Crumb detail**
- Full photo, poster's name/avatar, meal type, caption, ingredient tags (tappable → search), recipe (if any), restaurant (if any, tappable), neighborhood-level location label, time posted.
- Menu: **Report**, **Block user**.
- **No comment field, anywhere.**

### 3.5 Location privacy (important)
- Crumbs tagged at a restaurant use the restaurant's exact coordinates.
- Home/elsewhere crumbs: **round the coordinates on the device before sending them** and never store the raw location. Snap to a grid of roughly 1 km (e.g., round lat/lng to 2 decimal places, or use geohash precision 6 cell centers).
- Display home/elsewhere crumbs with a neighborhood or city label only (reverse geocode the rounded point, city/neighborhood level only).
- Never display a map pin for home/elsewhere crumbs.

### 3.6 Profiles ("Your trail")
- Your own profile: grid of your crumbs, edit profile, settings, blocked users list, delete account.
- Another user's profile: their visible crumbs, Report user, Block user.
- Users can edit their own caption, ingredients, and recipe, or delete their own crumb. Editing the photo is not allowed (delete and re-post instead).

### 3.7 Moderation (required for App Store approval)
**Report a crumb**
- Reasons: Inappropriate image, Offensive caption, Spam, Not food, Other (optional note, max 500 chars).
- One report per user per crumb.
- **Auto-hide:** when a crumb reaches 3 reports from different users, set `status = 'hidden'` automatically until an admin reviews it. Implement as a Postgres trigger.

**Block a user**
- Blocked users' crumbs never appear to the blocker in any feed, search, or restaurant page.
- The block is enforced in the database queries, not just the UI.

**Automatic image screening**
- Edge Function `moderate-crumb` runs after upload: sends the image to AWS Rekognition `DetectModerationLabels`.
- If any label in explicit/suggestive/violence/drugs/hate categories has confidence ≥ 80 → `status = 'rejected'`, notify the poster that the photo couldn't be posted.
- Otherwise → `status = 'visible'`.
- If moderation fails (error/timeout), leave `status = 'pending'` and add the crumb to the admin review queue.

**Caption/recipe text**
- Run a basic profanity/slur filter on caption, ingredients, and recipe before saving. Block the save with a friendly message if it matches.

**Admin page (web)**
- Admin-only (check `profiles.is_admin`).
- Queue of reported and pending crumbs, sorted oldest first, showing photo, caption, report count, and reasons.
- Actions: **Restore** (set visible, clear reports), **Remove** (set removed), **Ban user** (set `profiles.banned = true`, which hides all their crumbs and blocks new posts).
- Goal: act on reports within 24 hours.

**Contact**
- Settings screen includes a "Contact us" email link and links to Terms of Use and Privacy Policy.

---

## 4. Data Model (Supabase / Postgres)

Enable `postgis`. Use Row Level Security on every table.

```sql
create extension if not exists postgis;

create type meal_type as enum ('breakfast', 'lunch', 'dinner', 'snack');
create type crumb_status as enum ('pending', 'visible', 'hidden', 'rejected', 'removed');
create type location_kind as enum ('restaurant', 'approximate', 'none');

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  display_name text not null,
  avatar_url text,
  home_city text,
  is_admin boolean not null default false,
  banned boolean not null default false,
  terms_accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create table restaurants (
  id uuid primary key default gen_random_uuid(),
  google_place_id text unique not null,
  name text not null,
  address text,
  location geography(Point, 4326) not null,
  created_at timestamptz not null default now()
);
create index restaurants_location_idx on restaurants using gist (location);

create table crumbs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  photo_path text not null,
  meal_type meal_type not null,
  caption text check (char_length(caption) <= 280),
  ingredients text[] not null default '{}',
  recipe text check (char_length(recipe) <= 5000),
  restaurant_id uuid references restaurants(id),
  location_kind location_kind not null,
  location geography(Point, 4326),        -- null when location_kind = 'none'
  location_label text,                     -- e.g. "Alamo Heights, San Antonio"
  status crumb_status not null default 'pending',
  report_count int not null default 0,
  search_tsv tsvector generated always as (
    to_tsvector('english', coalesce(caption,'') || ' ' || coalesce(recipe,''))
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index crumbs_location_idx on crumbs using gist (location);
create index crumbs_ingredients_idx on crumbs using gin (ingredients);
create index crumbs_search_idx on crumbs using gin (search_tsv);
create index crumbs_feed_idx on crumbs (status, created_at desc);

create table reports (
  id uuid primary key default gen_random_uuid(),
  crumb_id uuid not null references crumbs(id) on delete cascade,
  reporter_id uuid not null references profiles(id) on delete cascade,
  reason text not null,
  note text check (char_length(note) <= 500),
  created_at timestamptz not null default now(),
  unique (crumb_id, reporter_id)
);

create table blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
```

### Required database logic
- **Trigger on `reports` insert:** increment `crumbs.report_count`; if it reaches 3, set `status = 'hidden'`.
- **RPC `crumbs_nearby(lat, lng, radius_miles, meal meal_type default null, cursor_created_at, cursor_id, page_size)`:** returns visible crumbs within radius using `ST_DWithin`, excluding crumbs from users the caller blocked, users who blocked the caller, and banned users.
- **RPC `search_crumbs(query text, lat, lng, radius_miles nullable, meal nullable, cursor..., page_size)`:** matches `ingredients @> array[lower(query)]` OR `search_tsv @@ websearch_to_tsquery('english', query)`, with the same block/ban/status exclusions. When radius is null, search everywhere.
- **RLS:**
  - `crumbs`: anyone signed in can read rows where `status = 'visible'`; owners can read all their own rows; owners can insert/update/delete their own rows but cannot change `status` or `report_count`; admins can read and update all.
  - `reports`: signed-in users can insert their own; only admins can read.
  - `blocks`: users manage only their own rows.
  - `profiles`: public read of non-sensitive fields; users update only their own row; `is_admin` and `banned` are not user-editable.
- **Storage policies:** users can upload/delete only under their own `{user_id}/` folder. Photos are served through signed URLs or a public bucket. Removed/rejected crumbs' photos are deleted by the admin action or moderation function.

---

## 5. Screens

1. **Welcome / Sign in** (email + Sign in with Apple)
2. **Onboarding:** username, display name, accept Terms, location permission prompt with a plain explanation
3. **Crumbs near you** (home feed with radius + meal filters)
4. **Search** (ingredient/recipe search with filters)
5. **Drop a crumb** (photo → meal type → where → caption/ingredients/recipe → post)
6. **Crumb detail** (report/block menu)
7. **Restaurant page**
8. **Profile / Your trail** (own and others')
9. **Settings** (edit profile, blocked users, contact us, terms, privacy policy, sign out, delete account)
10. **Admin web page** (separate web app)

Bottom tabs: **Near you · Search · Drop a crumb (center button) · Your trail**

Design feel: warm, cozy, and friendly. Photos are the focus, so big photo cards in the feed, with a clean layout and not much chrome.

---

## 6. Build Order

Build in these phases. Each phase should run end to end before starting the next.

1. **Foundation:** Expo app scaffold, Supabase project, schema + RLS, auth, onboarding, profile.
2. **Posting:** photo pick/compress/EXIF strip/upload, meal type, caption, ingredients, recipe, approximate location with rounding. Temporarily mark crumbs `visible` without moderation.
3. **Feed:** `crumbs_nearby` RPC, home feed with filters and pagination, crumb detail, profile trail.
4. **Restaurants:** Places Edge Functions, restaurant tagging in posting flow, restaurant page.
5. **Search:** `search_crumbs` RPC and Search tab.
6. **Moderation:** report + auto-hide trigger, block user, Rekognition Edge Function (switch posting to `pending` → moderated), text filter, admin web page, account deletion.
7. **Polish + store prep:** empty states, loading/error states, contact/terms/privacy links, app icon and splash, TestFlight build.

---

## 7. Acceptance Checklist

- [ ] A user can sign up, accept terms, and set a username.
- [ ] A user can post a crumb with a photo and meal type in under 30 seconds.
- [ ] Uploaded photos contain no EXIF/GPS metadata.
- [ ] Home/elsewhere crumbs are never stored or shown with an exact location.
- [ ] Restaurant-tagged crumbs show the restaurant and link to its page.
- [ ] "Crumbs near you" returns only crumbs within the chosen radius, filtered by meal type.
- [ ] Searching an ingredient returns crumbs tagged with it or mentioning it in the caption/recipe.
- [ ] There is no way to comment on any crumb.
- [ ] Reporting works; 3 reports from different users hides a crumb automatically.
- [ ] Blocking a user removes all their crumbs from the blocker's views.
- [ ] Explicit images are rejected by automatic screening.
- [ ] Admins can restore, remove, and ban from the admin page.
- [ ] A user can delete their account and all their data from inside the app.
- [ ] The Google Places and AWS keys are not present in the app bundle.

---

## 8. Not in v1 (decide later)

- A positive reaction button (e.g., "I'd eat that") or saving crumbs to a collection
- Following other users
- Multiple photos per crumb
- Promoted restaurant posts (possible revenue)
- Push notifications
- Android-specific polish (Expo builds Android, but test iOS first)