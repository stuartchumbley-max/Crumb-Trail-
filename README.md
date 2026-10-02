# Crumb Trail

Vibrant Expo / TypeScript / Expo Router foundation for the Crumb Trail mobile app.

## Implemented in this starter

- Three-screen feature tour with clearly marked sample photo cards.
- Apple and Google account creation, email/password signup and sign-in.
- Username and display-name onboarding with explicit Terms acceptance.
- Database-enforced lowercase unique usernames: 3–20 characters, first character a letter; letters, digits and underscores; reserved names rejected.
- Subscription paywall with Apple purchase / restore wiring through RevenueCat, localized store pricing, and introductory-offer eligibility lookup.
- Near you, Search, Drop a crumb and Your trail sample screens, clearly separated from real account data.
- Supabase account migration with column permissions that protect admin and ban flags.

## Run

```sh
npm install
npm run web
```

Copy `.env.example` to `.env` to connect services. With no credentials the tour and sample preview work; real signups and purchases show a configuration error instead of pretending to succeed.

## Connect accounts

1. Create a Supabase project and apply `supabase/migrations/001_accounts.sql`.
2. Add the project URL and anonymous/publishable key to `.env`. No service-role secret belongs in the app.
3. Enable email, Apple and Google providers in Supabase. Configure provider credentials and authorized redirect URLs. Allow `crumbtrail://auth/callback`; for web preview also allow the actual local web callback URL.
4. Set Supabase's minimum password length to 8. Email confirmation remains enabled. Production SMTP is required for reliable delivery.
5. Configure your Apple app identifier and Sign in with Apple capability, replacing the example bundle identifier.

## Apple subscription

The intended US offer is **3 days free, then $5.99/month**. Configure this in App Store Connect as a monthly auto-renewing subscription with a 3-day free-trial introductory offer. Apple decides trial eligibility; the app must not reset a trial on new account creation.

RevenueCat is the integration layer; Apple still processes the purchase. Create entitlement `crumb_trail`, attach the Apple product, and put it in the current offering's monthly package. Add the public iOS SDK key to `.env`. The paywall reads the live localized product price. Returning subscribers are not promised another free trial.

Real purchases require an iOS development build and sandbox/TestFlight testing. They cannot be validated in a web browser or standard Expo Go. Configure verified server webhooks and fill the server-owned membership table before adding paid feed/posting APIs; do not authorize content solely from a UI flag.

Configure Terms, Privacy and contact URLs before release. Draft legal copy and account deletion are not implemented yet.

## Next build phases

This is an initial foundation, not the completed v1. Still required: posting/image processing and EXIF verification, PostGIS crumb schema and paid access policies, nearby feed and pagination, places/geocoding functions, recipe search, reporting/blocking/moderation/admin review, account deletion including stored photos, legal pages, production branding, and iOS end-to-end testing.

Sample food photos load from Unsplash and are for the preview only. Replace them with owned assets before release. The included Expo template icon is temporary.
