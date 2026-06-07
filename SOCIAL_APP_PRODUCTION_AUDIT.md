# Social App Production Audit

This audit tracks the product, safety, backend, database, design, and release attributes expected for a social app like Construction Gossip. It is not a claim that every mature Facebook/Instagram/Threads-scale system is finished; it is the production baseline this app should be measured against before a public App Store launch.

## Reference Baseline

- Apple App Review Guideline 1.2 requires user-generated-content apps to include objectionable-content filtering, reporting, blocking, and reachable support contact information.
- OWASP MASVS calls out secure local storage and authentication/session handling as core mobile-app security areas.
- Supabase recommends Row Level Security for table access and storage access policies for file objects.

## Implemented

### Account And Identity

- Email/password signup and login through Supabase Auth.
- Keychain-backed storage for Supabase access, refresh, and user id session values.
- Terms of Use gate before account creation.
- Profile setup with optional photo, location, job/position, bio, and privacy controls.
- Duplicate username/email checks through the app flow and Supabase Auth.
- Sign out and account deletion entry point in settings.

### Social Graph

- Follow requests, following/follower counts, and accepted relationship state.
- Self-follow prevention.
- Blocking for profiles.

### Posting And Engagement

- Worker report posts with company, location, job, pay, conditions, recommendation, ratings, media, anonymity, and tags.
- Home feed, profile feeds, search results, comments, one-level replies, likes, and share links.
- One-like-per-user local behavior for posts, comments, and replies.
- Anonymous-post visibility rules so the author can see their own anonymous posts on their profile while other users cannot attribute them.
- Relative post dates for recent content.

### Discovery

- Search across people, posts, companies, location, job, and union/open-to-work-style filters.
- Clickable post attributes for company, job, and location discovery.
- State picker and larger city dataset with custom city entry.

### Messaging And Notifications

- Chat tab, conversations, text messages, image messages, and in-app post previews.
- Conversation sorting by newest activity.
- Notification tab and notification badge behavior.

### Media And Sharing

- Profile photo upload through Supabase Storage.
- Post, comment, and message image storage buckets.
- Native iOS share sheet with deep-link style app URLs.

### Refresh And Sync

- Pull-to-refresh on the primary data screens.
- Remote Supabase sync for profiles, posts, comments, likes, follow requests, friendships, blocks, conversations, and messages.

### Backend And Database

- Supabase tables for profiles, posts, comments, likes, follow requests, friendships, reports, blocks, conversations, members, and messages.
- Supabase storage buckets for profile photos, post images, comment images, and message images.
- Row Level Security policies for core ownership and participant-based access.
- User reporting for posts/comments and blocking for profiles.

### App Store And Documentation

- Support, privacy, review notes, and App Store checklist documents.
- README setup notes for Supabase schema, storage, migrations, privacy, and build steps.

## Needs Production Hardening Before Public Launch

### Safety And Moderation

- Move account deletion of `auth.users` to a trusted server-side Supabase Edge Function or admin backend.
- Add real moderation operations: review queue, admin tooling, takedown decisions, reporter feedback, and abuse-rate limits.
- Add reachable in-app support/contact flow for urgent abuse reports.
- Add appeal/review handling for removed content or blocked accounts.
- Add adult-content/harassment/private-information filtering before upload/post submission.
- Add automated spam controls for repeated posts, repeated comments, repeated friend requests, and repeated messages.

### Notifications And Realtime

- Add push notifications through APNs for follows, comments, likes, and messages.
- Add server-side notification rows instead of deriving badge counts only from local refreshed data.
- Add realtime subscriptions or polling windows for likes, follow requests, profile changes, and message delivery state.

### Scale And Performance

- Add stronger feed ranking and pagination for posts, comments, profiles, and messages.
- Add search indexes/full-text search for company, city, job, and usernames as data grows.
- Add cursor pagination for home feed, profile feed, search, comments, and chat history.
- Add image compression limits and upload retry behavior.
- Add cache invalidation rules so stale local data does not override newer server data.

### Privacy And Security

- Add private storage/signed URLs for sensitive media if public buckets are no longer acceptable.
- Add analytics/crash reporting with consent and privacy disclosures.
- Move production environment values into a per-environment config workflow.
- Add device/session management so users can sign out other sessions.
- Add password reset, email change, and account recovery flows inside the app.
- Add data export and deletion-completion confirmation.
- Add stricter database constraints for unique usernames, self-follows, duplicate friendships, duplicate likes, and invalid conversation membership.

### Product Completeness

- Add edit/delete controls for posts, comments, replies, and messages where appropriate.
- Add saved/bookmarked posts if the product needs repeat reference.
- Add profile verification or company affiliation proof if trust becomes important.
- Add onboarding prompts that explain anonymous posting and worker-report expectations.
- Add empty states and failure states for every networked screen.
- Add explicit deep-link handling for shared post URLs when the app is opened from outside.

### Design And Accessibility

- Run accessibility review for Dynamic Type, VoiceOver labels, color contrast, tap target size, and reduced motion.
- Add loading skeletons or progress states where remote fetches are slow.
- Confirm every screen works on small iPhones, large iPhones, light mode, and dark mode.

### Quality And Release

- Add automated tests for auth, posting, media upload, follow requests, likes, comments, replies, blocking, and account deletion.
- Add real support and legal URLs before App Store submission.
- Add App Store privacy nutrition labels, content moderation notes, review account credentials, and screenshots.
- Add crash reporting, release build archive validation, and TestFlight/internal testing before public release.
