create extension if not exists pgcrypto;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(char_length(display_name) between 1 and 40),
 birth_date date not null check(birth_date <= current_date - interval '21 years'),
 province text not null,
 district text not null,
 bio text default '',
 avatar_url text,
 created_at timestamptz default now(),
 updated_at timestamptz default now()
);

create table if not exists public.night_statuses(
 user_id uuid primary key references public.profiles(id) on delete cascade,
 province text not null,
 district text not null,
 place text not null check(place in ('home','out')),
 venue text,
 group_count int not null default 1 check(group_count between 1 and 30),
 status_bio text default '',
 expires_at timestamptz not null,
 updated_at timestamptz default now(),
 check(place <> 'home' or venue is null)
);

create table if not exists public.friend_requests(
 id uuid primary key default gen_random_uuid(),
 sender_id uuid not null references public.profiles(id) on delete cascade,
 receiver_id uuid not null references public.profiles(id) on delete cascade,
 status text not null default 'pending' check(status in('pending','accepted','declined')),
 created_at timestamptz default now(),
 check(sender_id<>receiver_id),
 unique(sender_id,receiver_id)
);

create table if not exists public.friendships(
 user_a uuid not null references public.profiles(id) on delete cascade,
 user_b uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz default now(),
 primary key(user_a,user_b),
 check(user_a::text<user_b::text)
);

create table if not exists public.messages(
 id bigint generated always as identity primary key,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 receiver_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(char_length(body) between 1 and 1000),
 created_at timestamptz default now()
);

create table if not exists public.blocks(
 blocker_id uuid not null references public.profiles(id) on delete cascade,
 blocked_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz default now(),
 primary key(blocker_id,blocked_id),
 check(blocker_id<>blocked_id)
);

create table if not exists public.reports(
 id bigint generated always as identity primary key,
 reporter_id uuid not null references public.profiles(id) on delete cascade,
 reported_id uuid not null references public.profiles(id) on delete cascade,
 reason text not null,
 detail text,
 created_at timestamptz default now()
);

create or replace view public.my_friends with(security_invoker=true) as
select case when f.user_a=auth.uid() then f.user_b else f.user_a end friend_id,
p.display_name,p.avatar_url,p.province,p.district,p.bio
from public.friendships f join public.profiles p
on p.id=case when f.user_a=auth.uid() then f.user_b else f.user_a end
where auth.uid() in(f.user_a,f.user_b);

create or replace view public.incoming_friend_requests with(security_invoker=true) as
select fr.id request_id,fr.sender_id,p.display_name,p.avatar_url,p.province,p.district
from public.friend_requests fr join public.profiles p on p.id=fr.sender_id
where fr.receiver_id=auth.uid() and fr.status='pending';

create or replace view public.discover_profiles with(security_invoker=true) as
select p.id,p.display_name,p.avatar_url,p.province,p.district,p.bio,
extract(year from age(current_date,p.birth_date))::int age,
s.place,s.venue,s.group_count,s.status_bio,s.expires_at
from public.profiles p
left join public.night_statuses s on s.user_id=p.id and s.expires_at>now()
where not exists(select 1 from public.blocks b where
(b.blocker_id=auth.uid() and b.blocked_id=p.id) or
(b.blocker_id=p.id and b.blocked_id=auth.uid()));

create or replace function public.are_friends(a uuid,b uuid)
returns boolean language sql stable security definer set search_path=public as $$
select exists(select 1 from public.friendships f
where f.user_a=least(a::text,b::text)::uuid and f.user_b=greatest(a::text,b::text)::uuid)
$$;

create or replace function public.accept_friend_request(p_request_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare r public.friend_requests; declare a uuid; declare b uuid;
begin
 select * into r from public.friend_requests where id=p_request_id for update;
 if r.receiver_id<>auth.uid() or r.status<>'pending' then raise exception 'Not allowed'; end if;
 a:=least(r.sender_id::text,r.receiver_id::text)::uuid;
 b:=greatest(r.sender_id::text,r.receiver_id::text)::uuid;
 insert into public.friendships(user_a,user_b) values(a,b) on conflict do nothing;
 update public.friend_requests set status='accepted' where id=p_request_id;
end $$;

alter table public.profiles enable row level security;
alter table public.night_statuses enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.messages enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;

create policy "profiles read" on public.profiles for select to authenticated using(true);
create policy "profile insert own" on public.profiles for insert to authenticated with check(id=auth.uid());
create policy "profile update own" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

create policy "status read" on public.night_statuses for select to authenticated using(expires_at>now() or user_id=auth.uid());
create policy "status insert own" on public.night_statuses for insert to authenticated with check(user_id=auth.uid());
create policy "status update own" on public.night_statuses for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "status delete own" on public.night_statuses for delete to authenticated using(user_id=auth.uid());

create policy "request read parties" on public.friend_requests for select to authenticated using(sender_id=auth.uid() or receiver_id=auth.uid());
create policy "request send own" on public.friend_requests for insert to authenticated with check(sender_id=auth.uid());
create policy "request receiver update" on public.friend_requests for update to authenticated using(receiver_id=auth.uid());

create policy "friendship read members" on public.friendships for select to authenticated using(user_a=auth.uid() or user_b=auth.uid());

create policy "messages read participants" on public.messages for select to authenticated using(sender_id=auth.uid() or receiver_id=auth.uid());
create policy "messages friends insert" on public.messages for insert to authenticated with check(sender_id=auth.uid() and public.are_friends(sender_id,receiver_id));

create policy "blocks read own" on public.blocks for select to authenticated using(blocker_id=auth.uid());
create policy "blocks insert own" on public.blocks for insert to authenticated with check(blocker_id=auth.uid());
create policy "blocks delete own" on public.blocks for delete to authenticated using(blocker_id=auth.uid());

create policy "reports insert own" on public.reports for insert to authenticated with check(reporter_id=auth.uid());
create policy "reports read own" on public.reports for select to authenticated using(reporter_id=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create policy "avatars public read" on storage.objects for select using(bucket_id='avatars');
create policy "avatars upload own" on storage.objects for insert to authenticated with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "avatars update own" on storage.objects for update to authenticated using(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "avatars delete own" on storage.objects for delete to authenticated using(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

alter publication supabase_realtime add table public.messages;