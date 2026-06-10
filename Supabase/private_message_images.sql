-- Apply once in the Supabase SQL editor after installing the matching app build.
-- Message images become private and can only be read or uploaded by members of
-- the conversation encoded in the storage path. Legacy messages/<uuid>-N.jpg
-- objects remain available to members of the message's conversation.

update storage.buckets
set public = false
where id = 'message-images';

create or replace function public.can_access_message_image(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, storage
as $$
declare
  folders text[] := storage.foldername(object_name);
  legacy_message_id text;
begin
  if folders[1] = 'conversations'
     and folders[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return public.is_conversation_member(folders[2]::uuid);
  end if;

  if folders[1] = 'messages' then
    legacy_message_id := regexp_replace(
      storage.filename(object_name),
      '-[0-9]+[.]jpg$',
      ''
    );

    if legacy_message_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
      return exists (
        select 1
        from public.messages
        where id = legacy_message_id::uuid
          and public.is_conversation_member(conversation_id)
      );
    end if;
  end if;

  return false;
end;
$$;

revoke all on function public.can_access_message_image(text) from public;
grant execute on function public.can_access_message_image(text) to authenticated;

drop policy if exists "public message images are readable" on storage.objects;
drop policy if exists "conversation members read message images" on storage.objects;
create policy "conversation members read message images"
on storage.objects for select to authenticated
using (
  bucket_id = 'message-images'
  and public.can_access_message_image(name)
);

drop policy if exists "authenticated users upload message images" on storage.objects;
drop policy if exists "conversation members upload message images" on storage.objects;
create policy "conversation members upload message images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'message-images'
  and public.can_access_message_image(name)
);
