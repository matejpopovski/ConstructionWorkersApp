grant usage on schema public to anon, authenticated;
grant usage on type public.pay_type to anon, authenticated;
grant usage on type public.union_status to anon, authenticated;
grant usage on type public.post_type to anon, authenticated;
grant usage on type public.friend_request_status to anon, authenticated;
grant usage on type public.message_visibility to anon, authenticated;
grant usage on type public.report_target_type to anon, authenticated;

grant select on public.profiles to anon, authenticated;
grant select on public.posts to anon, authenticated;
grant select on public.comments to anon, authenticated;
grant select on public.likes to anon, authenticated;

grant insert, update, delete on public.profiles to authenticated;
grant insert, update, delete on public.posts to authenticated;
grant insert, update, delete on public.comments to authenticated;
grant insert, delete on public.likes to authenticated;
grant select, insert, update, delete on public.friend_requests to authenticated;
grant select, insert, delete on public.friendships to authenticated;
grant select, insert on public.moderation_flags to authenticated;
grant select, insert, delete on public.blocked_users to authenticated;
grant select, insert, update on public.conversations to authenticated;
grant select, insert on public.conversation_members to authenticated;
grant select, insert on public.messages to authenticated;
