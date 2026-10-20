# Potato Farmers Market — starter package

## Contents
- `index.html`: responsive front-end prototype for the homepage, seller listing form, buyer enquiry form, sample price board, and personal forecast calculator.
- `schema.sql`: starter PostgreSQL/Supabase schema for accounts, listings, photos/evidence, enquiries, price observations, predictions, admin settings, and payment records.

## Open the prototype
Open `index.html` in a modern browser. The forms show local previews only. They do not persist data to a database or publish listings.

## Recommended production architecture
- Frontend: Next.js (or another maintained web framework)
- Database/auth/storage: Supabase/PostgreSQL
- Payments: server-verified M-Pesa integration
- Hosting: HTTPS-enabled managed hosting
- Charts: a chart library using saved market price observations

## Important before launch
1. Apply the schema in a development Supabase project and review it with a developer.
2. Add and test Row Level Security policies for every table and Storage bucket.
3. Build server-side listing creation, image upload, moderation, payment verification, subscription expiry, and contact-unlocking endpoints.
4. Seed listings should distinguish seller-stated generation from administrator-verified evidence.
5. Store a bag's actual kg weight separately from the local/common bag name. Do not assume a local name always means the same weight in every market.
6. Market prices must have a date, location, unit and source. Sample prices in the prototype are fictional examples.
7. Forecast submission is not the same as an AI price forecast. Start with farmer consensus and evaluate accuracy against recorded actual prices before presenting a model forecast.
8. Have local legal, privacy, tax, payment and seed-certification requirements reviewed before launch.

## MVP implementation order
1. Authentication and profiles
2. Seller listings + image storage + admin moderation
3. Buyer enquiries + seller responses
4. Adjustable fees + M-Pesa payment callbacks + protected contacts
5. Admin market price entry + trend charts
6. Community forecasts + participation counts + outcome tracking
