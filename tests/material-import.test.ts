import {test} from 'node:test';
import assert from 'node:assert/strict';
import ExcelJS from 'exceljs';
import {readFileSync} from 'node:fs';
import {detectMapping,validateImport} from '../src/features/materials/domain/import';
test('Excel: mapea columnas españolas, conserva decimales y rechaza duplicados y datos ambiguos',()=>{
 const map=detectMapping(['Código','Descripción','Unidad de medida','Stock','Precio unitario','Stock mínimo','Tipo']);
 const result=validateImport([['cab','Cable','metro',100,2.5,10,'consumible'],['test','Tester','unidad',2,85,1,'retornable']],map);
 assert.deepEqual(result.errors,[]);assert.equal(result.rows[0].sku,'CAB');assert.equal(result.rows[0].price,2.5);assert.equal(result.rows[1].kind,'returnable');
 assert.match(validateImport([['a','Cable','metro',1,2],['A','Cable','metro',2,2]],map).errors[0],/repetido/);
 assert.match(validateImport([['a','Cable','metro','1,500.50',2]],map).errors[0],/números/);
 assert.match(validateImport([['a','Cable','metro',-1,2]],map).errors[0],/números/);
 assert.match(validateImport([['a','Cable','metro',1,'']],map).errors[0],/Falta/);
});
test('la plantilla XLSX se puede leer con el mismo parser de la aplicación',async()=>{
 const book=new ExcelJS.Workbook();await book.xlsx.load(readFileSync('public/plantillas/materiales.xlsx') as unknown as ExcelJS.Buffer);
 const sheet=book.worksheets[0];const matrix:unknown[][]=[];sheet.eachRow(r=>matrix.push((r.values as unknown[]).slice(1)));
 const result=validateImport(matrix.slice(1),detectMapping(matrix[0]));assert.deepEqual(result.errors,[]);assert.equal(result.rows.length,3);assert.equal(result.rows.reduce((n,r)=>n+r.quantity*r.price,0),460);
});
