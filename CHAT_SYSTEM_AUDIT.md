# Chat System Audit

## Working

- Direct one-to-one chat UI and self-chat support
- Correct sender/receiver bubble placement
- Chronological message ordering and recent-conversation sorting
- Text, image, and shared-review messages
- Whitespace-only message rejection
- Message-ID deduplication
- Empty states, pull-to-refresh, and periodic foreground refresh
- Profile navigation from the conversation avatar
- Blocked-user filtering

## Fixed

- Replaced recursive `conversation_members` RLS checks with a security-definer membership helper
- Made direct-conversation creation atomic and removed the unsafe client fallback
- Prevented repeated send taps while a send is in progress
- Kept draft text and attachments when a send fails
- Cleared the composer only after server confirmation
- Added automatic scrolling to the newest message
- Added unread badges and per-member read timestamps
- Added a visible send progress state and actionable errors
- Preserved one direct conversation per user pair

## Intentionally Not Implemented

- Group conversations
- Video or arbitrary file attachments
- Typing indicators
- Delivered/seen receipts beyond read timestamps
- Reactions, reply-to-message, unsend, mute, and mark-unread actions
- APNs push notifications
- Server-driven realtime subscriptions; the current app polls every three seconds while chat screens are visible

## Remaining Production Work

- Run `Supabase/social_sync_fixes.sql` against the live Supabase project
- Add APNs and background notification handling before App Store release
- Add pagination before conversations routinely reach hundreds of messages
- Add automated integration tests using two authenticated test accounts
