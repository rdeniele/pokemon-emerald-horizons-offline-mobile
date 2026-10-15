import KeyIcon from "./KeyIcon";

export default function ControlGuide({compact=false}:{compact?:boolean}){
  return <span className={`control-guide ${compact?"control-guide-compact":""}`} aria-label="Keyboard and mouse controls">
    <span><span className="key-group">{Array.from("WASD").map(key=><KeyIcon key={key} letter={key}/>)}</span> Move</span>
    <span><i className="mouse-icon" aria-hidden="true"/> Mouse aim</span>
    {!compact&&<><span><span className="key-group">{Array.from("QERX").map(key=><KeyIcon key={key} letter={key}/>)}</span> Moves</span><span><kbd className="space-key">Space</kbd> Dodge</span></>}
    <span><KeyIcon letter="1"/>–<KeyIcon letter="6"/> Switch</span>
  </span>;
}
