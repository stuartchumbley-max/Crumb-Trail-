# Product decisions and build status

The original build specification is preserved in `docs-build-spec.md`.

## User decisions added September 30, 2026

- Vibrant colors, with food photography as the focus.
- Accounts required; include Create account with Apple and Create account with Google.
- Apple auto-renewable subscription, planned US price $5.99/month with a 3-day free trial for eligible customers.
- Present a few feature-tour screens with mockups before showing the subscription offer.
- Restrict usernames. Current rule: 3–20 lowercase letters, numbers and underscores, beginning with a letter; unique and reserved names blocked.

## Delivered starting point

Expo Router project and browser preview, three-screen feature tour, sample feed/search/profile tabs, email and social-auth integration code, profile onboarding and secure profile migration, and RevenueCat Apple purchase/restore integration code.

TypeScript checking and Expo web export succeeded. Tour and account options were inspected in the browser. Live accounts, Apple purchases, Supabase migrations and iOS builds have not been validated because service projects are not connected.

## Immediate next steps

Connect Supabase and apply the account migration; configure Apple and Google OAuth. Configure App Store Connect's monthly product and free trial, RevenueCat entitlement and offering, and an iOS development build. Test signup, returning sign-in, username uniqueness, offer eligibility, sandbox purchase, restore and expired membership before considering foundation complete.

Then follow the original build phases: posting, local feed, restaurants, search, moderation and store preparation. Paid APIs must verify active membership on the backend. A browser preview of the UI is not a completed mobile app.
