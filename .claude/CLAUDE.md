# xomfit-ios

> iOS app for social fitness & lifting tracker.

## What This Is
SwiftUI iOS app for workout logging, social fitness feed, personal record tracking, and friends system. Uses Supabase for auth and real-time data, with REST API calls to xomfit-backend.

## Stack
- Swift 6, SwiftUI, iOS 17+
- Supabase (auth & real-time DB)
- REST API (xomfit-backend)

## Key Commands
```bash
xcodebuild -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Important Paths
```
Xomfit/Xomfit/
  Models/         # data models
  Views/          # SwiftUI views
  ViewModels/     # MVVM view models
  Services/       # API + Supabase clients
  Utils/          # helpers
```

## Project Config
```yaml
pm_tool: github-projects
github_project_number: 2
github_project_owner: Xomware
base_branch: master
test_commands:
  - xcodebuild test -scheme Xomfit -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Constraints
- MVVM architecture — views should not call services directly
- Supabase handles auth — no custom auth logic
- iOS minimum target: iOS 17

## Lessons
