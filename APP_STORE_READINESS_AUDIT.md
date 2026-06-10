# Construction Gossip App Store Readiness Audit

Audit date: June 8, 2026

## A. Issues Found

### Critical

- Account deletion removed only the profile row and local cache, leaving the Supabase Auth user registered.
- The profile table stored a street address field while the entire profile row was readable through the Data API.
- Storage uploads had no owner update/delete policies, so replacing profile media and removing account media could fail.
- Users could report reviews and comments, but not profiles.
- Users could not delete their own comments or replies.
- Unblocking a user changed only local state and did not update Supabase.

### Release Blocking or High Risk

- Privacy Policy, Terms, and Support were not reachable from both the logged-out and logged-in app.
- The privacy policy described account deletion as incomplete and documented collection of a street address.
- Photo permission copy used the old CrewRate name and omitted message photos.
- No production moderation console exists. Reports are stored in Supabase and require a documented human review process.
- Message photos now use a private bucket, conversation-member policies, and temporary signed URLs.
- Many background refresh/mutation operations still suppress network errors and rely on local optimistic state.
- Feed, search, comments, and messages are not paginated, creating scale and memory risk.
- There are no automated UI/integration tests for authentication, uploads, messaging, moderation, or deletion.

### Submission Configuration

- Xcode signing team is blank.
- Final bundle identifier is `com.matejpopovski.ConstructionGossip`; register this exact identifier in Apple Developer.
- Version/build are still `1.0 (1)`.
- Public Privacy, Terms, and Support pages are hosted through GitHub Pages.
- Demo reviewer credentials are not yet entered in App Store Connect.

## B. Changes Made

- Added authenticated `delete_current_account()` RPC usage so deletion removes the Supabase Auth user and cascades related database data.
- Added media cleanup before account deletion and owner update/delete storage policies.
- Made account deletion asynchronous, preserving the signed-in account and showing an error if deletion fails.
- Removed street-address collection from Edit Profile and from the production schema/API row.
- Limited profile-table reads to authenticated users.
- Added delete controls for a user's own comments and replies.
- Added profile reporting for harassment, impersonation, and private information.
- Synced unblock actions to Supabase.
- Added Privacy Policy, Terms, and Support screens to login and Settings.
- Added progress/error handling for privacy settings and account deletion.
- Updated legal wording to match the current free app and Apple-only release.
- Updated the photo-library usage description with the current app name and purpose.
- Added a moderation operations runbook.
- Verified a simulator Debug build succeeds with Xcode 26.5 SDK.

## C. Remaining Rejection Risks

1. Apply `Supabase/app_store_readiness.sql` and test deletion with a disposable account. Until applied, Delete Account will fail.
2. Monitor private message-image delivery after release; the private bucket migration and two-account simulator test now pass.
3. Assign and operate a moderation queue. Apple Guideline 1.2 expects timely action, not only report buttons.
4. Add content filtering/rate limits for spam, threats, explicit content, harassment, and private information.
5. Improve network failure presentation for posting, deleting, following, liking, reporting, blocking, and refreshing.
6. Perform device testing on small/large iPhones, light/dark mode, Dynamic Type, VoiceOver, slow network, and offline mode.
7. Create pre-confirmed review accounts. Email confirmation is enabled, so Apple should not be asked to create or verify an account.
8. Monitor the public support request channel and Supabase moderation queue.
9. Archive a signed Release build and resolve any Organizer validation warnings.

## Privacy Label Inventory

All listed data is used for App Functionality, Account Management, Safety, and Security. It is linked to the user's identity and is not used for tracking.

- Contact Info: email address; optional first and last name.
- Identifiers: Supabase user ID and username.
- User Content: profile photo, job reviews, photos, comments, replies, likes, reports, blocks, and private messages.
- Coarse Location: user-entered city and state.
- Sensitive Info: optional union status.
- Financial Info / Other Financial Info: optional pay type and pay amount.
- Other Data: job/position, employer, experience, certifications, benefits, languages, bio, recommendation and workplace ratings, privacy preferences, follow graph, and timestamps.
- Not collected by app code: contacts, precise GPS, microphone/audio, camera capture, health, fitness, advertising ID, payment card details, browsing history, analytics events, crash logs, or push tokens.
- Verify Supabase production log retention for IP address and user-agent/device metadata before finalizing the labels and privacy policy.

## Permissions

- Photos: selected through Apple's PhotosPicker only; the usage description explains profile, review, comment, and message uploads.
- Camera: not requested.
- Location: not requested; city/state are typed or selected.
- Microphone: not requested.
- Notifications: push permission is not requested; notifications are currently in-app.
- Contacts: not requested.

## D. Manual App Store Connect Work

- Create the app record using the final bundle ID and signing team.
- Enter two durable, pre-confirmed demo accounts and passwords in App Review Information.
- Publish and enter HTTPS Privacy Policy, Terms, and Support URLs.
- Write the final description, subtitle, keywords, promotional text, copyright, and support contact.
- Capture accurate screenshots from the submitted build for required iPhone sizes.
- Complete privacy labels using the inventory above.
- Complete the age-rating questionnaire. Start from 17+ expectations because of UGC, anonymous workplace complaints, photos, and private messaging.
- Select Social Networking as the primary category.
- State that there are no purchases, subscriptions, or paid digital features.
- Provide review notes below and a direct contact who can answer reviewer questions.
- Apply the Supabase migration and verify the production moderation/support process before uploading.

## E. Draft App Review Notes

Construction Gossip is a social/community app for construction workers to share job reviews, pay and safety context, photos, comments, and private messages.

Demo accounts:

- Account 1: `[REVIEWER_EMAIL_1]` / `[REVIEWER_PASSWORD_1]`
- Account 2: `[REVIEWER_EMAIL_2]` / `[REVIEWER_PASSWORD_2]`

Both accounts are pre-confirmed. No phone verification, invitation, payment, or external hardware is required.

Suggested review path:

1. Sign in with Account 1.
2. Use Post to publish a job review with optional company, job, location, pay, ratings, anonymity, and photo.
3. Open the new review from Home or Profile. Use its menu to report or delete it.
4. Add a comment and reply. A user can delete their own comment/reply or report another user's content.
5. Use Search to find reviews, workers, companies, jobs, and locations.
6. Open Account 2's profile to follow, message, report, block, or unblock that user.
7. Open Chat to exchange text, photos, and review links between the two demo accounts.
8. Open the notification bell for follow requests, likes, comments, and replies.
9. Open Profile > Settings for privacy controls, Privacy Policy, Terms, Support, Sign Out, and permanent Delete Account.

Anonymous reviews hide the author from other users but retain the account association for moderation. User reports are written to the Supabase moderation queue.

Support: https://matejpopovski.github.io/ConstructionWorkersApp/support.html
