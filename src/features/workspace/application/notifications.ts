'use server';
import {requireUser} from '@/features/auth/application/session';
import type {Row} from '../domain/types';
export async function readNotifications(){
 const {client,user}=await requireUser();
 const [list,count]=await Promise.all([client.from('notifications').select('id,organization_id,title,body,action_url,read_at,created_at').eq('recipient_user_id',user.id).order('created_at',{ascending:false}).limit(100),client.from('notifications').select('id',{head:true,count:'exact'}).eq('recipient_user_id',user.id).is('read_at',null)]);
 return {items:(list.data??[]) as Row[],count:count.count??0,error:!!(list.error||count.error)};
}
export async function markNotificationsRead(id?:string){
 const {client,user}=await requireUser();
 let query=client.from('notifications').update({read_at:new Date().toISOString()}).eq('recipient_user_id',user.id).is('read_at',null);
 if(id)query=query.eq('id',id);
 const {error}=await query;return {ok:!error};
}
