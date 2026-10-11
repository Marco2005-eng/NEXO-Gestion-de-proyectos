export const importFields = ['sku','name','unit','quantity','price','minimum','kind'] as const;
export type ImportField = typeof importFields[number];
export type ImportMaterial = {sku:string;name:string;unit:string;quantity:number;price:number;minimum:number;kind:string};
export type Mapping = Record<ImportField,number>;
export const captions:Record<ImportField,string> = {sku:'Código / SKU',name:'Material',unit:'Unidad',quantity:'Cantidad',price:'Precio unitario (S/)',minimum:'Stock mínimo',kind:'Tipo'};
const aliases:Record<ImportField,string[]> = {sku:['sku','codigo','codigomaterial','cod'],name:['material','nombre','descripcion','producto'],unit:['unidad','unidaddemedida','medida'],quantity:['cantidad','stock','existencias','stockinicial'],price:['precio','preciounitario','costounitario','costo'],minimum:['minimo','stockminimo'],kind:['tipo','tipodematerial']};
export function detectMapping(headers:unknown[]):Mapping {const normalize=(v:unknown)=>String(v??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z]/g,'');return Object.fromEntries(importFields.map(f=>[f,headers.findIndex(h=>aliases[f].includes(normalize(h)))])) as Mapping;}
function number(value:unknown,optional=false) {if(value===null||value===undefined||String(value).trim()===''){if(optional)return 0;throw new Error('Falta cantidad o precio.');}const raw=typeof value==='number'?value:String(value).trim().replace(',','.');const n=Number(raw);if(!Number.isFinite(n)||n<0||n>1000000||Math.abs(n*10000-Math.round(n*10000))>0.001)throw new Error('Usa números entre 0 y 1 000 000, con hasta 4 decimales; sin separadores de miles.');return n;}
export function validateImport(matrix:unknown[][],mapping:Mapping) {
 const rows:ImportMaterial[]=[];const errors:string[]=[];const seen=new Set<string>();
 if(['sku','name','unit','quantity','price'].some(f=>mapping[f as ImportField]<0))return {rows,errors:['Relaciona las cinco columnas obligatorias.']};
 const selected=importFields.map(f=>mapping[f]).filter(i=>i>=0);if(new Set(selected).size!==selected.length)return {rows,errors:['Cada campo debe usar una columna diferente.']};
 if(matrix.length>1000)return {rows,errors:['Máximo 1 000 filas por importación.']};
 matrix.forEach((r,i)=>{if(!r.some(v=>v!==null&&v!==undefined&&String(v).trim()!==''))return;try{
  const get=(f:ImportField)=>mapping[f]<0?undefined:r[mapping[f]];
  const sku=String(get('sku')??'').trim().toUpperCase(),name=String(get('name')??'').trim(),unit=String(get('unit')??'').trim();
  if(!sku||sku.length>40||!name||name.length>200||!unit||unit.length>40)throw new Error('Completa código (máx. 40), nombre (máx. 200) y unidad (máx. 40).');
  if(seen.has(sku))throw new Error('Código repetido: '+sku);seen.add(sku);
  const rawKind=String(get('kind')??'consumable').trim().toLowerCase()||'consumable';const kind=({consumible:'consumable',retornable:'returnable',equipo:'returnable'} as Record<string,string>)[rawKind]??rawKind;
  if(!['consumable','returnable'].includes(kind))throw new Error('Tipo: consumible o retornable.');
  rows.push({sku,name,unit,quantity:number(get('quantity')),price:number(get('price')),minimum:number(get('minimum'),true),kind});
 }catch(e){errors.push('Fila '+(i+2)+': '+(e instanceof Error?e.message:'Datos inválidos.'));}});
 if(!rows.length&&!errors.length)errors.push('El archivo no contiene materiales.');return {rows,errors};
}
