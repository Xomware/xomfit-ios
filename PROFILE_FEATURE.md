# User Profile Feature Documentation

## Overview

This document describes the User Profile implementation for the XomFit iOS app, which allows users to create and manage their workout profiles with avatar uploads, bio, stats display, and privacy controls.

## Features Implemented

### 1. Profile Creation & Setup
- Display user information (username, display name, bio)
- Avatar upload capability with image picker
- Profile creation flow integrated with auth system
- Public/private profile toggle

### 2. Avatar Upload
- Image selection from photo library
- JPEG compression at 80% quality
- Storage in Supabase Storage (`avatars` bucket)
- Automatic public URL generation
- AsyncImage for efficient loading with fallback UI

### 3. Bio & User Information
- Text field for user bio (150 character limit)
- Display name editing
- Real-time character count display
- Validation and error handling

### 4. Lifetime Stats Display
- **Total Workouts**: Count of all completed workouts
- **Total Volume**: Sum of all weights lifted (displayed in thousands of lbs)
- **Personal Records**: Display of recent PRs with exercise name, weight, and reps
- **Streak**: Current and longest streak tracking
- **Favorite Exercise**: Most frequently lifted exercise
- Stats computed from workout data

### 5. Privacy Controls
- Public/private profile toggle
- Displays lock icon for private profiles
- Privacy status updates persisted to auth metadata
- Privacy control in edit mode

## Architecture

### Data Models

#### User Model
```swift
struct User: Codable, Identifiable {
    let id: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var bio: String
    var stats: UserStats
    var isPrivate: Bool
    var createdAt: Date
}

struct UserStats: Codable {
    var totalWorkouts: Int
    var totalVolume: Double // in lbs
    var totalPRs: Int
    var currentStreak: Int
    var longestStreak: Int
    var favoriteExercise: String?
}
```

### Services

#### UserProfileService
Handles all profile-related backend operations:
- `uploadAvatar(imageData:userId:)` - Upload avatar to Supabase Storage
- `updateUserProfile(...)` - Update user profile metadata
- `deleteAvatar(avatarPath:)` - Delete avatar from storage

#### AuthService
Manages authentication and user state:
- Sign in/sign up flow
- Session management
- User metadata updates

### ViewModels

#### ProfileViewModel
Manages profile UI state and interactions:
- Display and edit mode state management
- Form validation
- Avatar image selection
- Profile update coordination
- Error handling

### Views

#### ProfileView
Container view that switches between display and edit modes

#### ProfileDisplayView
Displays user profile information:
- Avatar with fallback placeholder
- User information
- Privacy status indicator
- Stats grid (workouts, PRs, streak)
- Total volume display
- Recent personal records
- Edit button
- Sign out button

#### EditProfileView
Allows users to edit profile information:
- Avatar upload with image picker
- Display name field
- Bio field with character limit
- Privacy toggle
- Save/Cancel actions
- Error message display

#### ImagePicker
UIViewControllerRepresentable wrapper for iOS photo library access

## File Structure

```
XomFit/
├── Models/
│   └── User.swift (UserStats struct)
├── Services/
│   ├── AuthService.swift
│   ├── UserProfileService.swift (NEW)
│   └── SupabaseClient.swift
├── ViewModels/
│   └── ProfileViewModel.swift (ENHANCED)
└── Views/
    └── Profile/
        └── ProfileView.swift (ENHANCED)

XomFitTests/
├── ProfileViewModelTests.swift (NEW)
└── UserProfileServiceTests.swift (NEW)
```

## Usage

### Basic Profile Display
```swift
ProfileView()
    .environmentObject(authService)
```

### Profile Editing
Users tap the "Edit Profile" button to enter edit mode, which allows:
1. Change avatar via photo library
2. Update display name
3. Update bio (max 150 chars)
4. Toggle privacy status
5. Save or cancel changes

## Integration with Backend

### Supabase Storage Setup
The implementation requires:
1. Supabase Storage bucket named "avatars"
2. Proper RLS policies for authenticated users
3. Public access for avatar URLs

### Supabase Auth Metadata
User metadata stored in auth.users:
- `avatar_url`: URL to avatar image
- `display_name`: User's display name
- `bio`: User biography
- `is_private`: Privacy setting boolean

## Testing

### Unit Tests

#### ProfileViewModelTests.swift
- Edit mode initialization
- Value restoration on cancel
- Form field updates
- Privacy toggle
- Stats display

#### UserProfileServiceTests.swift
- Service initialization
- User profile data structure
- Privacy toggle
- Validation logic
- Error handling

### Running Tests
```bash
cd /Users/dom/Code/xomfit-ios
xcodebuild test -scheme XomFit
```

## Future Enhancements

1. **Profile Verification**
   - Email verification
   - Badge system for verified users

2. **Extended Stats**
   - Workout history charts
   - Weekly/monthly progress
   - Body composition tracking

3. **Social Features**
   - View friend profiles
   - Follow/unfollow users
   - Profile activity feed

4. **Data Export**
   - Export profile data
   - Share profile stats

5. **Image Optimization**
   - Image compression pipeline
   - Thumbnail generation
   - Multiple format support

## Known Limitations

1. **Image Size**: Limited to device memory for JPEG encoding
2. **Character Limits**: Bio limited to 150 characters
3. **No Offline Mode**: Profile updates require network connectivity
4. **Single Avatar**: Only one avatar per user

## Error Handling

The implementation includes error handling for:
- Network failures during avatar upload
- Invalid image formats
- Metadata update failures
- Storage quota exceeded

Errors are displayed to users in edit mode with clear messaging.

## Performance Considerations

1. **Image Loading**: AsyncImage with loading state to prevent UI blocking
2. **Memory Management**: JPEG compression at 80% quality
3. **Lazy Loading**: Stats computed on demand from workout data
4. **Caching**: Supabase handles URL caching for avatars

## Security

1. **Authentication**: All operations require authenticated user
2. **Authorization**: Users can only edit their own profiles
3. **Storage**: Avatars stored in secure Supabase Storage
4. **Privacy**: Private profiles enforce read restrictions
5. **Data Validation**: Input validation on all user fields

## Dependencies

- **SwiftUI**: UI framework
- **Supabase Swift**: Backend services and storage
- **Foundation**: Core functionality

## Version History

- **v1.0** (2026-02-26): Initial implementation
  - Profile display
  - Avatar upload
  - Bio editing
  - Privacy toggle
  - Stats display
  - Unit tests
