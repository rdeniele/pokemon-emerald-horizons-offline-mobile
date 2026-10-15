"use client";

/** Shared next steps for wins and losses across PvE, matchmaking and friend rooms. */
export default function BattleActions({onAgain,onParty,onMain,againLabel="Battle again",againDisabled=false,busy=false}:{onAgain:()=>void;onParty:()=>void;onMain:()=>void;againLabel?:string;againDisabled?:boolean;busy?:boolean}) {
  return <div className="battle-result-actions" aria-label="After battle actions">
    <button className="primary-action" disabled={busy||againDisabled} onClick={onAgain}>{againLabel}</button>
    <button disabled={busy} onClick={onParty}>Party & PC</button>
    <button disabled={busy} onClick={onMain}>{busy?"Saving…":"Main menu"}</button>
  </div>;
}
