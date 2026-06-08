-- Run this once in Supabase SQL Editor.
-- Repairs recursive chat RLS, creates direct conversations atomically,
-- and adds durable per-user read timestamps.

alter table public.conversation_members
add column if not exists last_read_at timestamptz not null default now();

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
  order by cm1.created_at
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

revoke all on function public.get_or_create_direct_conversation(uuid) from public;
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

drop policy if exists "members view conversations" on public.conversations;
drop policy if exists "authenticated users create conversations" on public.conversations;
drop policy if exists "members view conversation members" on public.conversation_members;
drop policy if exists "members add conversation members" on public.conversation_members;
drop policy if exists "members view messages" on public.messages;
drop policy if exists "members send messages" on public.messages;

create policy "members view conversations"
on public.conversations for select
to authenticated
using (public.is_conversation_member(id));

create policy "members view conversation members"
on public.conversation_members for select
to authenticated
using (public.is_conversation_member(conversation_id));

create policy "members view messages"
on public.messages for select
to authenticated
using (public.is_conversation_member(conversation_id));

create policy "members send messages"
on public.messages for insert
to authenticated
with check (
  auth.uid() = sender_id
  and public.is_conversation_member(conversation_id)
);

drop policy if exists "friendships visible to participants" on public.friendships;
drop policy if exists "friendships are readable" on public.friendships;
create policy "friendships are readable"
on public.friendships for select
to authenticated
using (true);
