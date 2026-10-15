"use client";
import Link from 'next/link';
import UiIcon from './stages/UiIcon';
import {useEffect,useState} from 'react';
import {makeStore,type Save} from '@/offline/model';
export default function HomeMenu(){
 const [summary,setSummary]=useState<Save|null|undefined>(undefined),[error,setError]=useState('');
 useEffect(()=>{try{setSummary(makeStore().load() as Save|null);}catch(e){setError(String(e));setSummary(null);}},[]);
 const btn='rounded-lg py-3 text-center font-semibold';
 return <nav className="flex w-full flex-col gap-3"><Link href="/game/" className={`${btn} bg-emerald-500 text-lg font-bold text-black hover:bg-emerald-400`}><UiIcon name="challenge"/>{summary?'Continue challenge':'Choose your starter'}{summary&&<span className="block text-xs font-normal">{summary.party.length} partners · {Math.min(8,summary.cleared.length)}/8 badges · {summary.gold} gold</span>}</Link>{error&&<p role="alert">{error}</p>}<div className="grid grid-cols-2 gap-3"><Link href="/game/" className="home-party rounded-lg bg-white/10 py-2 text-sm font-semibold"><UiIcon name="collection"/>Party & PC</Link><Link href="/game/" className="home-arena rounded-lg bg-white/10 py-2 text-sm font-semibold"><UiIcon name="challenge"/>Explore & battle</Link></div><div className="flex items-center justify-between rounded-lg bg-white/5 px-3 py-2 text-xs"><span>Offline adventure · Your progress stays on this device</span></div></nav>;
}
