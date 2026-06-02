# ConstructionWorkersApp

Construction Gossip is an MVP native iPhone app for U.S. construction workers to connect, post, compare workplace/pay experiences, search workers and companies, and manage friends.

## What is Included

- SwiftUI iOS app target: `CrewRate`
- Clean MVVM-style folders: `Models`, `Views`, `ViewModels`, `Services`, `Components`, `Utilities`
- Core tabs: Home, Search, Create Post, Friends, Profile
- Auth, signup, login, optional onboarding, profile editing, privacy settings
- Construction employer reviews, pay/work condition reports, anonymous posting, one-like-per-user reactions, comments, one-level replies, sharing, and report placeholders
- Search across people, posts, companies, location, trade, and open-to-work filters
- Friend requests, friends list, and messaging placeholder
- Supabase schema, RLS policies, storage buckets, and seed data

## Open in Xcode

Open `CrewRate.xcodeproj` from this repository root.

The app currently uses local demo services so the UI can run before Supabase credentials are configured. The service files are intentionally named for the production surface area:

- `AuthService`
- `ProfileService`
- `PostService`
- `CommentService`
- `LikeService`
- `FriendService`
- `StorageService`
- `SearchService`
- `ModerationService`

## Supabase Setup

1. Create a Supabase project.
2. In the Supabase SQL editor, run `Supabase/schema.sql`.
3. For demo content, run `Supabase/seed.sql`.
4. Confirm these storage buckets exist:
   - `profile-photos`
   - `post-images`
   - `comment-images`
5. Replace the local demo service implementations with Supabase client calls.

## Privacy Notes

- Street address is modeled as `street_address_private_only` and is never rendered in public profile UI.
- Pay, company, trade, city, and state are optional.
- Anonymous posting is supported.
- Work reports show a warning before posting.
- Reports and block-user placeholders are included for moderation expansion.

## Build

From the repo root:

```sh
xcodebuild -project CrewRate.xcodeproj -scheme CrewRate -destination 'generic/platform=iOS Simulator' build
```
