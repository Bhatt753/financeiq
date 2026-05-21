# RupeeIQ Flutter App

Android app for the RupeeIQ Smart Budget Planner.

## Backend
- URL: `https://financeiq-kqi9.onrender.com`
- API prefix: `/api/`
- Auth: JWT Bearer tokens (60-day expiry)

## Setup

```bash
cd rupeeiq_flutter
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Features
- Login / Register
- Dashboard — income, expenses, savings, goals overview
- Add Monthly Data — with SMS auto-fill from bank messages
- History — monthly records with detail view
- Loan Tracker — add/delete loans, EMI analysis
- Goal Planner — set goals, analyze feasibility
- Financial Health Score — grade, components, priority actions
- Profile — view and edit account

## SMS Auto-fill
Tap the SMS icon on the Add Data screen. The app reads recent bank SMS messages,
parses transaction amounts, suggests categories, and pre-fills the expense form.

Requires READ_SMS permission (prompted on first use).

## API Endpoints added to Flask
All endpoints under `/api/` — see `routes/api.py`.
Existing web routes are unchanged.

## Colors (dark theme)
| Token     | Hex       |
|-----------|-----------|
| bg        | #0F172A   |
| surface   | #1E293B   |
| green     | #4ADE80   |
| red       | #EF4444   |
| amber     | #F59E0B   |
| indigo    | #6366F1   |
| text      | #F1F5F9   |
| textSub   | #94A3B8   |
