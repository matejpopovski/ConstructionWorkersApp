# ConstructionWorkersApp

## Confidentiality and Proprietary Rights

This repository, source code, product concept, designs, workflows, data models, business logic, branding, and related materials are confidential, proprietary, and intended solely for authorized development of Construction Gossip. This project is not open source. No license is granted, implied, or otherwise, to copy, distribute, publish, reuse, modify, reverse engineer, commercialize, or incorporate any portion of this codebase or product concept into another project without prior written permission from the owner.

All rights are reserved. The owner may pursue copyright, trade secret, trademark, contract, patent, patent-pending, and any other applicable intellectual-property protections to the fullest extent permitted by law. Any person or entity that takes, copies, republishes, sells, derives value from, or otherwise uses any part of this repository, whether in full or in part, may be subject to legal action, damages, injunctive relief, and review by a court of competent jurisdiction.

Access to this repository does not constitute permission to use it. If you are not expressly authorized to view or work on this project, you must stop using it, delete any copies in your possession, and notify the owner immediately.

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
