"use client";
import {useEffect,useState} from "react";

/** Short screens show fewer entries rather than hiding entries below the fold. */
export function usePageSizes() {
  const [size,setSize]=useState({cards:4,rows:3});
  useEffect(()=>{
    const resize=()=>{
      const columns=window.innerWidth<640?2:3;
      const height=window.visualViewport?.height??window.innerHeight;
      setSize({cards:columns*Math.max(1,Math.min(3,Math.floor((height-380)/158))),rows:Math.max(1,Math.min(6,Math.floor((height-380)/88)))});
    };
    resize();window.addEventListener("resize",resize);window.visualViewport?.addEventListener("resize",resize);
    return()=>{window.removeEventListener("resize",resize);window.visualViewport?.removeEventListener("resize",resize);};
  },[]);
  return size;
}
export function pageIndex(page:number,total:number,size:number) {return Math.min(page,Math.max(0,Math.ceil(total/size)-1));}
export default function Pager({page,total,size,onChange,label}:{page:number;total:number;size:number;onChange:(page:number)=>void;label:string}) {
  const current=pageIndex(page,total,size),pages=Math.max(1,Math.ceil(total/size));
  return <nav className="list-pager" aria-label={`${label} pages`}><button disabled={!current} onClick={()=>onChange(current-1)} aria-label={`Previous ${label} page`}>Previous</button><span aria-live="polite">{total?`${current*size+1}–${Math.min(total,(current+1)*size)} of ${total}`:"0 results"} <small>Page {current+1}/{pages}</small></span><button disabled={current+1>=pages} onClick={()=>onChange(current+1)} aria-label={`Next ${label} page`}>Next</button></nav>;
}
