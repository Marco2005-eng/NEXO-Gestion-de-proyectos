-- Ejecuta después de SQL 11. Esta cuenta será el proveedor de Nexo.
-- Cambia el correo si quieres utilizar otra cuenta existente de Authentication.
begin;
do $$
declare v_email text:='2023100659@ucss.pe';v_user uuid;
begin
 select id into v_user from auth.users where lower(email)=lower(v_email);
 if v_user is null then raise exception 'El correo no existe en Authentication: %',v_email; end if;
 insert into public.platform_administrators(user_id) values(v_user) on conflict do nothing;
end $$;
commit;
