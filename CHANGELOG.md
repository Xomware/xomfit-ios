# Changelog

All notable changes to XomFit iOS are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Sprint 3: Advanced Analytics & AI] — 2026-03-01

### Added
- **Video Analysis & Recovery Insights** — Analyze exercise form from video clips, receive AI-driven recovery recommendations based on workout data
- **Health Integrations & Export** — Connect with Apple Health, integrate HealthKit data, export and share workout reports
- **AI Coach Recommendations** — Intelligent coaching suggestions based on workout patterns and performance trends
- **Advanced Stats** — Deep performance analytics including estimated one-rep max (1RM) trends, volume tracking, intensity distribution
- **Custom Programs** — Create, customize, and manage personalized training programs tailored to user goals
- **Social Leaderboards** — Compete with friends and community on lift records, total volume, and workout streaks

### Fixed
- Fixed EstimatedOneRMChart averageScaled calculation bug (PR #61)

### Documentation
- Updated README with comprehensive feature list (PR #65)

---

## [Sprint 2: Marketplace, Form Check & Polish] — 2026-02-28

### Added
- **Web App** — Browser-based Next.js version of XomFit for desktop access and workout planning
- **Workout Marketplace** — Discover, share, and import community-created training programs
- **Form Check Videos** — Attach instructional video clips to exercises and sets for form guidance and progress tracking
- **Push Notifications** — APNs integration with customizable workout reminders, alerts, and deep linking
- **Gym Check-in** — Location-based gym check-ins with ability to see friends currently at the same gym
- **Body Composition Tracking** — Track weight, body measurements, progress photos, and visualize composition changes with charts

### Improved
- **Auth Integration & Polish** — Comprehensive testing and refinement of authentication flows with improved error handling

### Workflow
- Added PR template and SwiftLint configuration for code quality (PR #67)
- Added CI/CD pipeline and Dependabot automation (PR #66)

---

## [Sprint 1: Core Fitness Experience] — 2026-02-28

### Added
- **Complete Auth Suite** — Multi-method authentication including Apple Sign-in, Google Sign-in, Email/Password, and Supabase session management
- **Workout Logger** — Fast, intuitive set logging with built-in timer and customizable rest periods
- **PR (Personal Record) Tracking** — Automatically track and celebrate personal bests across all exercises
- **Friends System** — Follow friends, view their profiles, and compare performance metrics
- **Social Feed** — Activity feed showing friend workouts, milestones, and social engagement with filtering options
- **Analytics** — Basic charting and tracking of workout volume, frequency, and performance trends
- **Stick Figure Animations** — Visual exercise form guides using animated stick figures for proper technique reference
- **Workout Challenges** — Create and participate in timed fitness challenges with friends and community
- **Live Workout Mode** — Real-time workout tracking with countdown timers, set/rep counters, and rest reminders
- **User Profile** — Customizable user profiles with stats, goals, and personal information management

### Infrastructure
- Integrated Supabase as backend and authentication provider
- Set up database schema for users, workouts, exercises, and social features

---

## [Initial Setup & Onboarding] — 2026-02-25

### Added
- **Supabase Auth Integration** — Foundation for multi-method authentication (Apple, Email/Password)

### Infrastructure
- Project initialization and repository setup
- Basic authentication flow implementation

---

## Unreleased

---

## Roadmap & Future Features

- Real-time multiplayer workout sessions
- Advanced recovery tracking with wearable integration
- Nutrition and macro tracking
- AI-powered workout recommendations based on performance patterns
- Enhanced video analysis with ML-powered form detection
- Internationalization and localization
- Offline mode for workouts without internet connection

---

*Generated from git commit history. Last updated: March 1, 2026*
