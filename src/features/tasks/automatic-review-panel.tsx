'use client';
import type {Row} from '@/features/workspace/domain/types';
import {Icon} from '@/components/shared/icon';
import {automaticReview} from './automatic-review';
export function AutomaticReviewPanel({submission,evidence,onManualReview}:{submission:Row;evidence:Row[];onManualReview?:()=>void}){
 const checks=automaticReview(submission,evidence);const observationCount=checks.filter(c=>c.observation).length;
 const observations=observationCount===1?'1 observación':observationCount?`${observationCount} observaciones`:'';
 return <section className="automatic-review-panel" aria-label="Revisión automática preliminar"><div className="automatic-review-heading"><span className="automatic-review-icon"><Icon name="check" size={18}/></span><div><h4>Revisión automática preliminar</h4><p>Controles de descripción, archivos y porcentaje · resultado inmediato</p></div><span className={'tag '+(observations?'automatic-review-attention':'')}>{observations?observations:'Sin alertas de formato'}</span>{onManualReview&&<button className="button secondary small" type="button" onClick={onManualReview}>Revisar manualmente</button>}</div><div className="automatic-review-checks">{checks.map(c=><div className={'automatic-review-check '+(c.observation?'has-observation':'')} key={c.id}><span className="automatic-review-mark" aria-hidden="true">{c.observation?'!':'✓'}</span><div><strong>{c.title}</strong><p>{c.detail}</p></div></div>)}</div><p className="automatic-review-limit">Estos controles no analizan el contenido visual de las fotos ni aprueban el trabajo. El supervisor puede revisar y decidir manualmente aunque haya observaciones.</p></section>;
}

