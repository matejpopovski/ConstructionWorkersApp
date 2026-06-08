create extension if not exists "pgcrypto";

drop table if exists public.messages cascade;
drop table if exists public.conversation_members cascade;
drop table if exists public.conversations cascade;
drop table if exists public.blocked_users cascade;
drop table if exists public.moderation_flags cascade;
drop table if exists public.friendships cascade;
drop table if exists public.friend_requests cascade;
drop table if exists public.likes cascade;
drop table if exists public.comments cascade;
drop table if exists public.posts cascade;
drop table if exists public.profiles cascade;

drop type if exists public.report_target_type cascade;
drop type if exists public.message_visibility cascade;
drop type if exists public.friend_request_status cascade;
drop type if exists public.post_type cascade;
drop type if exists public.union_status cascade;
drop type if exists public.pay_type cascade;

create type public.pay_type as enum ('hourly', 'salary', 'piece-rate', 'contract');
create type public.union_status as enum ('union', 'non-union', 'prefer not to say');
create type public.post_type as enum ('general', 'work_report');
create type public.friend_request_status as enum ('pending', 'accepted', 'rejected');
create type public.message_visibility as enum ('everyone', 'friends', 'no_one');
create type public.report_target_type as enum ('post', 'comment', 'profile');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  first_name text,
  last_name text,
  profile_photo_url text,
  state text,
  city text,
  street_address_private_only text,
  trade_position text,
  custom_trade_position text,
  experience_level text,
  current_company_or_employer text,
  pay_type public.pay_type,
  pay_amount numeric(12,2),
  union_status public.union_status,
  years_experience int check (years_experience is null or years_experience >= 0),
  certifications text[] not null default '{}',
  benefits_received text[] not null default '{}',
  languages_spoken text[] not null default '{}',
  bio text,
  open_to_work boolean not null default false,
  willing_to_relocate boolean not null default false,
  show_real_name boolean not null default false,
  show_current_company boolean not null default false,
  show_pay_on_profile boolean not null default false,
  show_city_state boolean not null default false,
  allow_friend_requests boolean not null default true,
  allow_messages_from public.message_visibility not null default 'friends',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'username', ''), split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_type public.post_type not null default 'general',
  text_content text,
  image_urls text[] not null default '{}',
  is_anonymous boolean not null default false,
  company_or_employer text,
  trade_position text,
  custom_trade_position text,
  city text,
  state text,
  pay_type public.pay_type,
  pay_amount numeric(12,2),
  overtime_available boolean,
  benefits text[] not null default '{}',
  supervisor_flexibility_rating int check (supervisor_flexibility_rating between 1 and 5),
  treatment_rating int check (treatment_rating between 1 and 5),
  safety_rating int check (safety_rating between 1 and 5),
  workload_rating int check (workload_rating between 1 and 5),
  pay_fairness_rating int check (pay_fairness_rating between 1 and 5),
  would_recommend boolean,
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint post_has_content check (
    text_content is not null
    or cardinality(image_urls) > 0
    or post_type = 'work_report'
  )
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  text_content text,
  image_urls text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint comment_has_content check (text_content is not null or cardinality(image_urls) > 0)
);

create table public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint one_like_target check (
    (post_id is not null and comment_id is null)
    or (post_id is null and comment_id is not null)
  ),
  unique (user_id, post_id),
  unique (user_id, comment_id)
);

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status public.friend_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint no_self_friend_request check (sender_id <> receiver_id),
  unique (sender_id, receiver_id)
);

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint no_self_friendship check (user_id <> friend_id),
  unique (user_id, friend_id)
);

create table public.moderation_flags (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type public.report_target_type not null,
  target_id uuid not null,
  reason text not null,
  notes text,
  created_at timestamptz not null default now()
);

create table public.blocked_users (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint no_self_block check (blocker_id <> blocked_id),
  unique (blocker_id, blocked_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversation_members (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text,
  image_urls text[] not null default '{}',
  shared_post_id uuid references public.posts(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint message_has_content check (
    body is not null
    or cardinality(image_urls) > 0
    or shared_post_id is not null
  )
);

create index profiles_username_idx on public.profiles (lower(username));
create index profiles_location_idx on public.profiles (state, city);
create index profiles_trade_idx on public.profiles (trade_position);
create index posts_company_idx on public.posts (lower(company_or_employer));
create index posts_location_idx on public.posts (state, city);
create index posts_trade_idx on public.posts (trade_position);

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

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.moderation_flags enable row level security;
alter table public.blocked_users enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create or replace function public.is_conversation_member(target_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members
    where conversation_id = target_conversation_id
      and user_id = auth.uid()
  );
$$;

revoke all on function public.is_conversation_member(uuid) from public;
grant execute on function public.is_conversation_member(uuid) to authenticated;

create or replace function public.get_or_create_direct_conversation(other_user_id uuid)
returns table (get_or_create_direct_conversation uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  found_conversation_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (select 1 from public.profiles where id = other_user_id) then
    raise exception 'Recipient profile does not exist';
  end if;

  select cm1.conversation_id
  into found_conversation_id
  from public.conversation_members cm1
  join public.conversation_members cm2
    on cm2.conversation_id = cm1.conversation_id
  where cm1.user_id = current_user_id
    and cm2.user_id = other_user_id
    and (
      select count(*)
      from public.conversation_members members
      where members.conversation_id = cm1.conversation_id
    ) = case when current_user_id = other_user_id then 1 else 2 end
  limit 1;

  if found_conversation_id is null then
    insert into public.conversations default values
    returning id into found_conversation_id;
    insert into public.conversation_members (conversation_id, user_id)
    values (found_conversation_id, current_user_id);
    if other_user_id <> current_user_id then
      insert into public.conversation_members (conversation_id, user_id)
      values (found_conversation_id, other_user_id);
    end if;
  end if;

  return query select found_conversation_id;
end;
$$;

grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;

create or replace function public.mark_direct_conversation_read(other_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  target_conversation_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  select cm1.conversation_id
  into target_conversation_id
  from public.conversation_members cm1
  join public.conversation_members cm2
    on cm2.conversation_id = cm1.conversation_id
  where cm1.user_id = current_user_id
    and cm2.user_id = other_user_id
  limit 1;

  if target_conversation_id is not null then
    update public.conversation_members
    set last_read_at = now()
    where conversation_id = target_conversation_id
      and user_id = current_user_id;
  end if;
end;
$$;

revoke all on function public.mark_direct_conversation_read(uuid) from public;
grant execute on function public.mark_direct_conversation_read(uuid) to authenticated;

create policy "profiles are readable" on public.profiles for select using (true);
create policy "users insert own profile" on public.profiles for insert with check (auth.uid() = id);
create policy "users update own profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "posts are readable" on public.posts for select using (true);
create policy "users create own posts" on public.posts for insert with check (auth.uid() = user_id);
create policy "users update own posts" on public.posts for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users delete own posts" on public.posts for delete using (auth.uid() = user_id);

create policy "comments are readable" on public.comments for select using (true);
create policy "users create own comments" on public.comments for insert with check (auth.uid() = user_id);
create policy "users update own comments" on public.comments for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users delete own comments" on public.comments for delete using (auth.uid() = user_id);

create policy "likes are readable" on public.likes for select using (true);
create policy "users create own likes" on public.likes for insert with check (auth.uid() = user_id);
create policy "users delete own likes" on public.likes for delete using (auth.uid() = user_id);

create policy "friend requests visible to participants" on public.friend_requests for select using (auth.uid() in (sender_id, receiver_id));
create policy "send own friend request" on public.friend_requests for insert with check (auth.uid() = sender_id);
create policy "receiver updates request" on public.friend_requests for update using (auth.uid() = receiver_id) with check (auth.uid() = receiver_id);
create policy "participants delete request" on public.friend_requests for delete using (auth.uid() in (sender_id, receiver_id));

create policy "friendships are readable" on public.friendships for select to authenticated using (true);
create policy "friendships inserted by participant" on public.friendships for insert with check (auth.uid() in (user_id, friend_id));
create policy "friendships deleted by participant" on public.friendships for delete using (auth.uid() in (user_id, friend_id));

create policy "users create reports" on public.moderation_flags for insert with check (auth.uid() = reporter_id);
create policy "users view own reports" on public.moderation_flags for select using (auth.uid() = reporter_id);

create policy "users view own blocks" on public.blocked_users for select using (auth.uid() = blocker_id);
create policy "users create own blocks" on public.blocked_users for insert with check (auth.uid() = blocker_id);
create policy "users delete own blocks" on public.blocked_users for delete using (auth.uid() = blocker_id);

create policy "members view conversations" on public.conversations for select using (
  public.is_conversation_member(id)
);
create policy "members view conversation members" on public.conversation_members for select using (
  public.is_conversation_member(conversation_id)
);
create policy "members view messages" on public.messages for select using (
  public.is_conversation_member(conversation_id)
);
create policy "members send messages" on public.messages for insert with check (
  auth.uid() = sender_id
  and public.is_conversation_member(conversation_id)
);

insert into storage.buckets (id, name, public)
values
  ('profile-photos', 'profile-photos', true),
  ('post-images', 'post-images', true),
  ('comment-images', 'comment-images', true),
  ('message-images', 'message-images', true)
on conflict (id) do nothing;

create policy "public profile photos are readable" on storage.objects for select using (bucket_id = 'profile-photos');
create policy "public post images are readable" on storage.objects for select using (bucket_id = 'post-images');
create policy "public comment images are readable" on storage.objects for select using (bucket_id = 'comment-images');
create policy "public message images are readable" on storage.objects for select using (bucket_id = 'message-images');

create policy "authenticated users upload profile photos" on storage.objects for insert to authenticated with check (bucket_id = 'profile-photos');
create policy "authenticated users upload post images" on storage.objects for insert to authenticated with check (bucket_id = 'post-images');
create policy "authenticated users upload comment images" on storage.objects for insert to authenticated with check (bucket_id = 'comment-images');
create policy "authenticated users upload message images" on storage.objects for insert to authenticated with check (bucket_id = 'message-images');
