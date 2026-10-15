import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Emerald Horizons — Unofficial Fan-Made Pokémon Game",
  description: "An unofficial fan-made Pokémon game. Challenge Hoenn stages, catch your team and train offline. Not affiliated with Nintendo, Game Freak or Creatures.",
};

export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#32645c", viewportFit: "cover" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="flex min-h-full flex-col">
        {children}
      </body>
    </html>
  );
}
