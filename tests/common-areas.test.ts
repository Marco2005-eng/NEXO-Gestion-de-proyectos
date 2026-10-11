import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
test('áreas comunes: diez por organización sin duplicar nombres ni repetir la carga',async()=>{
 const db=new PGlite();try{
 await db.exec(`create table organizations(id uuid primary key default gen_random_uuid(),name text,deleted_at timestamptz);
 create table areas(id uuid primary key default gen_random_uuid(),organization_id uuid references organizations(id),code text,name text,description text,is_active boolean,deleted_at timestamptz,unique(organization_id,code));
 insert into organizations(name) values('Primera'),('Segunda');
 insert into areas(organization_id,code,name,is_active) select id,'TI-PREVIA','Tecnologia',true from organizations where name='Primera';`);
 const sql=await readFile('supabase/18_areas_comunes.sql','utf8');await db.exec(sql);await db.exec(sql);
 const counts=await db.query<{total:number}>('select count(*)::int total from areas group by organization_id');
 assert.deepEqual(counts.rows.map(r=>r.total),[10,10]);
 assert.equal((await db.query<{total:number}>("select count(*)::int total from areas where name='Tecnologia'")).rows[0].total,1);
 }finally{await db.close();}
});
