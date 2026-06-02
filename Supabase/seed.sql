insert into public.profiles (id, username, state, city, trade_position, union_status, years_experience, open_to_work, show_city_state)
select
  gen_random_uuid(),
  'worker_' || gs,
  (array['CA','TX','FL','IL','NY','OH','AZ','GA','PA','NC'])[1 + (gs % 10)],
  (array['Los Angeles','Austin','Tampa','Chicago','Buffalo','Columbus','Phoenix','Atlanta','Pittsburgh','Charlotte'])[1 + (gs % 10)],
  (array['Carpenter','Electrician','Plumber','Concrete Finisher','Heavy Equipment Operator','Roofer','Welder','Foreman','HVAC Technician','General Laborer'])[1 + (gs % 10)],
  (array['union','non-union','prefer not to say']::public.union_status[])[1 + (gs % 3)],
  1 + (gs % 20),
  gs % 4 = 0,
  true
from generate_series(1, 20) gs;

insert into public.posts (
  user_id,
  post_type,
  text_content,
  is_anonymous,
  company_or_employer,
  trade_position,
  city,
  state,
  pay_type,
  pay_amount,
  overtime_available,
  benefits,
  supervisor_flexibility_rating,
  treatment_rating,
  safety_rating,
  workload_rating,
  pay_fairness_rating,
  would_recommend,
  tags
)
select
  p.id,
  case when gs % 3 = 0 then 'work_report'::public.post_type else 'general'::public.post_type end,
  case when gs % 3 = 0
    then 'Work report: solid crew, realistic schedule, and pay matched what was promised.'
    else 'Jobsite check-in: what tools or safety gear are people liking this week?'
  end,
  gs % 11 = 0,
  case when gs % 3 = 0 then (array['Turner','Morton Builders','Lone Star Electric','Buckeye Civil','Sunbelt Roofing'])[1 + (gs % 5)] else null end,
  p.trade_position,
  p.city,
  p.state,
  case when gs % 3 = 0 then 'hourly'::public.pay_type else null end,
  case when gs % 3 = 0 then 22 + (gs % 30) else null end,
  gs % 2 = 0,
  case when gs % 3 = 0 then array['Health insurance','PTO'] else '{}' end,
  1 + (gs % 5),
  1 + ((gs + 1) % 5),
  1 + ((gs + 2) % 5),
  1 + ((gs + 3) % 5),
  1 + ((gs + 4) % 5),
  gs % 4 <> 0,
  array[p.trade_position, p.city]
from generate_series(1, 50) gs
join lateral (
  select * from public.profiles order by random() limit 1
) p on true;

insert into public.comments (post_id, user_id, text_content)
select post_id, user_id, text_content
from (
  select
    posts.id as post_id,
    profiles.id as user_id,
    (array['Good info, thanks for sharing.','How was the overtime?','That matches what I heard locally.','Safety culture matters a lot on that kind of site.'])[1 + (row_number() over () % 4)] as text_content
  from public.posts
  cross join lateral (select id from public.profiles order by random() limit 1) profiles
  limit 80
) seeded_comments;

insert into public.comments (post_id, user_id, parent_comment_id, text_content)
select c.post_id, p.id, c.id, 'Replying with a little more context for the thread.'
from public.comments c
cross join lateral (select id from public.profiles order by random() limit 1) p
limit 25;
