create extension if not exists "pgcrypto";

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

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_type public.post_type not null default 'general',
  text_content text,
  image_urls text[] not null default '{}',
  is_anonymous boolean not null default false,
  company_or_employer text,
  trade_position text,
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
  created_at timestamptz not null default now(),
  unique (conversation_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  image_urls text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index profiles_search_idx on public.profiles using gin (
  to_tsvector('english', coalesce(username, '') || ' ' || coalesce(city, '') || ' ' || coalesce(state, '') || ' ' || coalesce(trade_position, '') || ' ' || coalesce(current_company_or_employer, ''))
);
create index posts_search_idx on public.posts using gin (
  to_tsvector('english', coalesce(text_content, '') || ' ' || coalesce(company_or_employer, '') || ' ' || coalesce(city, '') || ' ' || coalesce(state, '') || ' ' || coalesce(trade_position, '') || ' ' || array_to_string(tags, ' '))
);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.moderation_flags enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

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

create policy "friendships visible to participants" on public.friendships for select using (auth.uid() in (user_id, friend_id));
create policy "friendships inserted by participant" on public.friendships for insert with check (auth.uid() in (user_id, friend_id));
create policy "friendships deleted by participant" on public.friendships for delete using (auth.uid() in (user_id, friend_id));

create policy "users create reports" on public.moderation_flags for insert with check (auth.uid() = reporter_id);
create policy "users view own reports" on public.moderation_flags for select using (auth.uid() = reporter_id);

create policy "members view conversations" on public.conversations for select using (
  exists (select 1 from public.conversation_members cm where cm.conversation_id = id and cm.user_id = auth.uid())
);
create policy "members view conversation members" on public.conversation_members for select using (
  exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid())
);
create policy "members view messages" on public.messages for select using (
  exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid())
);
create policy "members send messages" on public.messages for insert with check (
  auth.uid() = sender_id
  and exists (select 1 from public.conversation_members cm where cm.conversation_id = conversation_id and cm.user_id = auth.uid())
);

insert into storage.buckets (id, name, public)
values
  ('profile-photos', 'profile-photos', true),
  ('post-images', 'post-images', true),
  ('comment-images', 'comment-images', true)
on conflict (id) do nothing;
