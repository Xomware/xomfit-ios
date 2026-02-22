# XomFit 💪

**Social fitness & lifting tracker for iOS**

Train together. Get stronger. XomFit lets you log workouts, track PRs, and see what your friends are lifting — all in one app.

## Features

### MVP
- 📰 **Social Feed** — See friends' workouts, PRs, and activity
- 📝 **Workout Logger** — Fast, minimal-tap workout logging
- 🏋️ **Exercise Library** — Comprehensive database with muscle groups
- 📋 **Workout Builder** — Create and save custom templates
- 🏆 **PR Tracking** — Auto-detect and celebrate personal records
- 👥 **Friends System** — Follow friends, compare progress
- 📊 **Analytics** — Progress charts and volume tracking

### Coming in V1
- 🤖 AI Coach — Personalized workout recommendations
- 🎨 Stick figure exercise animations
- 🎯 Workout challenges between friends
- 📹 Form check videos
- 🔴 Live workout mode

## Architecture

- **Pattern:** MVVM (Model-View-ViewModel)
- **UI:** SwiftUI
- **Theme:** Dark mode with green accent (#33FF66)
- **Minimum iOS:** 17.0

### Project Structure
```
XomFit/
├── XomFitApp.swift          # App entry point
├── Models/                  # Data models (Codable structs)
├── Views/
│   ├── Feed/               # Social feed
│   ├── Workout/            # Workout logging & builder
│   ├── Progress/           # Analytics & charts
│   ├── Profile/            # User profile
│   ├── Auth/               # Login & sign up
│   └── Common/             # Reusable components
├── ViewModels/             # Business logic
├── Services/               # API & auth services
└── Utils/                  # Theme, extensions, constants
```

## Getting Started

1. Clone the repo
2. Open in Xcode 15+
3. Build and run on iOS 17+ simulator

## Related Repos

- [xomfit-backend](https://github.com/Xomware/xomfit-backend) — API backend
- [xomfit-infrastructure](https://github.com/Xomware/xomfit-infrastructure) — Terraform/AWS infra

## Part of [Xomware](https://xomware.com)
