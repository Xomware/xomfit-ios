# XomFit 💪

**Social fitness & lifting tracker for iOS**

Train together. Get stronger. XomFit lets you log workouts, track PRs, and see what your friends are lifting — all in one app.

## Features

### Core Workout Features
- 📰 **Social Feed** — See friends' workouts, PRs, and activity  
- 📝 **Workout Logger** — Fast, minimal-tap workout logging with timer and rest timer
- 🏋️ **Exercise Library** — Comprehensive database with muscle groups
- 📋 **Workout Builder** — Create and save custom templates
- 🏆 **PR Tracking** — Auto-detect and celebrate personal records
- 👥 **Friends System** — Follow friends, compare progress
- 📊 **Analytics** — Progress charts and volume tracking

### Sprint 2: Advanced Features
- 🤖 **AI Coach** — Personalized workout recommendations based on your history
- 🎨 **Stick Figure Animations** — Exercise form guides for proper technique
- 🎯 **Workout Challenges** — Create and compete in challenges with friends
- 📹 **Form Check Videos** — Attach video clips to sets for form analysis
- 🔴 **Live Workout Mode** — Real-time workout streaming with friends

### Sprint 3: Comprehensive Suite
- 💪 **Body Composition** — Weight tracking, measurements, progress photos, charts
- 📍 **Gym Check-in** — Location-based check-in, see who's at your gym
- 🔔 **Push Notifications** — Workout reminders, friend activity, deep links
- 🛍️ **Workout Marketplace** — Share and import community workout programs
- 📈 **Advanced Stats & Analytics** — Estimated 1RM, volume trends, muscle group analysis
- 🎬 **Video Analysis** — Form correction feedback with video insights
- 🔋 **Recovery Insights** — Recovery tracking and recommendations
- 🏥 **Health Kit Integration** — Sync with Apple Health for holistic tracking
- 📤 **Export & Share** — Export workouts, achievements, and progress reports
- 🏅 **Social Leaderboards** — Compete with friends across various metrics
- 📚 **Custom Programs** — Build and save personalized training programs

### Web App
- 🌐 **Web Dashboard** — Next.js browser version for tracking and planning on desktop

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
│   ├── BodyComposition/    # Weight & measurements tracking
│   ├── GymCheckIn/         # Location-based check-in
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
3. Build and run on iOS 17+ simulator or device

## Tech Stack

- **Backend:** [xomfit-backend](https://github.com/Xomware/xomfit-backend) (API server)
- **Web:** [xomfit-web](https://github.com/Xomware/xomfit-web) (Next.js dashboard)
- **Infrastructure:** [xomfit-infrastructure](https://github.com/Xomware/xomfit-infrastructure) (Terraform/AWS)
- **Authentication:** Supabase (Apple, Google, Email/Password)
- **Database:** PostgreSQL
- **Cloud:** AWS

## Development

### Build Requirements
- Xcode 15 or later
- iOS 17+ deployment target

### Contributing
We welcome contributions! Please:
1. Fork the repo
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'feat: description'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

## Part of [Xomware](https://xomware.com)
