import ControlGuide from "@/components/stages/ControlGuide";
import HomeMenu from "@/components/HomeMenu";
import Link from "next/link";
import "@/components/stages/stages.css";

export default function Home() {
  return (
    <main className="stage-app stage-home">
      <div className="dialogue-panel">
        <h1>Emerald Horizons</h1>
        <p>
          Explore nine regional challenges from Kanto to Paldea and catch your team, completely offline. Take direct control
          with the touch joystick and move buttons—or WASD, mouse aiming, Q/E/R/X and Space. Gain EXP, evolve your partners and restore the beacons.
        </p>
      </div>
      <HomeMenu />
      <ControlGuide/>
      <Link className="credits-link" href="/credits">Credits & thanks</Link>
      <p>
        Unofficial fan-made game. Pokémon and related names, characters and artwork belong to their respective owners, including Nintendo, Game Freak and Creatures. This project is not endorsed by them.
      </p>
    </main>
  );
}
