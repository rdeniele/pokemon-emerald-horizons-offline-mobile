"use client";
import {useState} from "react";

export default function KeyIcon({letter}:{letter:string}){
  const [loaded,setLoaded]=useState(false);
  const digit=/^[0-9]$/.test(letter);
  const row=digit?(letter==="0"?25:15+Number(letter)):letter.charCodeAt(0)-65;
  return <kbd className="key-icon" aria-label={letter}>
    <span style={{visibility:loaded?"hidden":"visible"}}>{letter}</span>
    {/* The local sheet is optional; retain the readable key label when absent. */}
    {/* eslint-disable-next-line @next/next/no-img-element */}
    <img src="/assets/vryell/keyboard.png" alt="" ref={image=>{if(image?.complete&&image.naturalWidth)setLoaded(true);}} onLoad={()=>setLoaded(true)} onError={()=>setLoaded(false)} style={{display:loaded?"block":"none",top:-row*16,left:digit?-16:0}}/>
  </kbd>;
}
