-- Perfil personal. El número de identidad solo es consultable por su propietario.
begin;
create table if not exists public.personal_profile_details (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 identity_type text check(identity_type in ('dni','ce','passport')),
 identity_number text check(length(identity_number)<=30),
 updated_at timestamptz not null default now(),
 check((identity_type is null)=(identity_number is null))
);
alter table public.personal_profile_details enable row level security;
drop policy if exists personal_profile_select_self on public.personal_profile_details;
create policy personal_profile_select_self on public.personal_profile_details for select to authenticated using(user_id=auth.uid());
grant select on public.personal_profile_details to authenticated;
revoke insert,update,delete on public.personal_profile_details from authenticated,anon;
create or replace function public.nexo_update_personal_profile(p_payload jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare v_name text:=trim(coalesce(p_payload->>'display_name',''));
 v_phone text:=nullif(trim(p_payload->>'phone'),'');
 v_type text:=nullif(p_payload->>'identity_type','');
 v_number text:=nullif(trim(p_payload->>'identity_number'),'');
begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
 if length(v_name)=0 or length(v_name)>150 or length(coalesce(p_payload->>'first_name',''))>100 or length(coalesce(p_payload->>'last_name',''))>100 then raise exception 'Revisa los nombres del perfil'; end if;
 if v_phone is not null and (length(v_phone)>30 or v_phone!~'^[+0-9 ()-]{6,30}$') then raise exception 'Revisa el teléfono'; end if;
 if (v_type is null)<>(v_number is null) then raise exception 'Completa el tipo y número de documento, o deja ambos vacíos'; end if;
 if v_type='dni' and v_number!~'^[0-9]{8}$' then raise exception 'El DNI debe tener 8 dígitos'; end if;
 if v_number is not null and v_number!~'^[A-Za-z0-9-]{4,30}$' then raise exception 'Revisa el número de documento'; end if;
 update public.profiles set display_name=v_name,first_name=nullif(trim(p_payload->>'first_name'),''),last_name=nullif(trim(p_payload->>'last_name'),''),phone=v_phone where id=auth.uid();
 insert into public.personal_profile_details(user_id,identity_type,identity_number) values(auth.uid(),v_type,v_number)
 on conflict(user_id) do update set identity_type=excluded.identity_type,identity_number=excluded.identity_number,updated_at=now();
end $$;
revoke all on function public.nexo_update_personal_profile(jsonb) from public,anon;
grant execute on function public.nexo_update_personal_profile(jsonb) to authenticated;
commit;
