import {requireUser} from '@/features/auth/application/session';
import {ProfileForm} from '@/features/profile/profile-form';
export default async function ProfilePage(){
 const {client,user}=await requireUser();
 const [profile,identity]=await Promise.all([client.from('profiles').select('display_name,first_name,last_name,phone').eq('id',user.id).single(),client.from('personal_profile_details').select('identity_type,identity_number').eq('user_id',user.id).maybeSingle()]);
 if(profile.error)return <div className="page-content"><h1>Mi perfil</h1><p>No se pudo cargar el perfil. Recarga la página para volver a intentarlo.</p></div>;
 return <ProfileForm profile={profile.data??{}} email={user.email??''} identity={identity.data??{}} ready={!identity.error}/>;
}
