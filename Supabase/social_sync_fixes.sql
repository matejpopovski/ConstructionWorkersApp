-- Run this once in Supabase SQL Editor.
-- It makes direct-conversation creation atomic and permits follower/following lists.

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

drop policy if exists "friendships visible to participants" on public.friendships;
create policy "friendships are readable"
on public.friendships for select
to authenticated
using (true);
