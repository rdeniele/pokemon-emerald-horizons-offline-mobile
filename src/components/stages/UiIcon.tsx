import Image from "next/image";

export type UiIconName="challenge"|"collection"|"settings"|"trainer"|"check"|"locked"|"home"|"close";
export default function UiIcon({name}:{name:UiIconName}){
  return <Image className="ui-pixel-icon" src={`/assets/humble-paper/icons/${name}.png`} width={24} height={24} alt="" aria-hidden="true" unoptimized/>;
}
