-- Apply once in the Supabase SQL editor before testing account deletion.
-- This migration removes an unused sensitive field, limits profile reads to
-- signed-in users, permits owners to replace/delete their uploads, and adds
-- an authenticated self-service account deletion RPC.

alter table public.profiles
  drop column if exists street_address_private_only;

revoke select on public.profiles from anon;
grant select on public.profiles to authenticated;

drop policy if exists "profiles are readable" on public.profiles;
drop policy if exists "profiles are readable to signed-in users" on public.profiles;
create policy "profiles are readable to signed-in users" on public.profiles
for select to authenticated using (true);

create or replace function public.delete_current_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;

  delete from auth.users where id = current_user_id;
  if not found then
    raise exception 'Account not found';
  end if;
end;
$$;

revoke all on function public.delete_current_account() from public;
grant execute on function public.delete_current_account() to authenticated;

drop policy if exists "owners update uploaded images" on storage.objects;
create policy "owners update uploaded images" on storage.objects
for update to authenticated
using (
  bucket_id in ('profile-photos', 'post-images', 'comment-images', 'message-images')
  and owner_id = auth.uid()::text
)
with check (
  bucket_id in ('profile-photos', 'post-images', 'comment-images', 'message-images')
  and owner_id = auth.uid()::text
);

drop policy if exists "owners delete uploaded images" on storage.objects;
create policy "owners delete uploaded images" on storage.objects
for delete to authenticated
using (
  bucket_id in ('profile-photos', 'post-images', 'comment-images', 'message-images')
  and owner_id = auth.uid()::text
);
