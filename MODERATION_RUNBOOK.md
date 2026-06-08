# Moderation Runbook

Construction Gossip accepts user reports for reviews, comments, replies, and profiles. Reports are stored in `public.moderation_flags` in Supabase.

## Daily Review

1. Review new rows in `moderation_flags`, newest first.
2. Inspect the referenced content and surrounding context.
3. Prioritize threats, illegal content, exposed private information, impersonation, hate speech, and targeted harassment.
4. Remove violating content from the relevant Supabase table.
5. For repeated or severe abuse, disable or delete the account in Supabase Authentication.
6. Preserve only the minimum records needed for fraud prevention, legal obligations, or an active dispute.

## Response Targets

- Credible threats, child safety issues, or exposed highly sensitive information: immediate review.
- Harassment, hate speech, impersonation, scams, and illegal content: within 24 hours.
- Spam, misinformation, and lower-risk policy violations: within 72 hours.

## Escalation

- Contact emergency services when legally required for an imminent threat.
- Preserve relevant evidence before removal when required by law.
- Direct copyright, privacy, and account appeals to `support@constructiongossip.app`.

## Release Requirement

Before public launch, assign a real person to this queue, verify the support inbox works, and document who has authority to remove content or suspend accounts. Reports must not be allowed to accumulate without review.
