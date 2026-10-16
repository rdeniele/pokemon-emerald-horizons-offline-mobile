'use client';

import { useState } from 'react';

export default function Game() {
  const [message, setMessage] = useState('');
  async function fullscreen() {
    try {
      await document.documentElement.requestFullscreen();
      const orientation = screen.orientation as ScreenOrientation & { lock?: (value: string) => Promise<void> };
      await orientation.lock?.('landscape').catch(() => {});
      setMessage('');
    } catch {
      setMessage('Rotate your phone to landscape. Fullscreen is available in the Android app.');
    }
  }
  return (
    <main className="game-shell">
      <iframe title="Pokémon Prototype Mobile" src="/game/index.html" allow="autoplay; fullscreen; gamepad" allowFullScreen />
      <button className="fullscreen" onClick={fullscreen} aria-label="Enter fullscreen landscape"><svg width="16" height="16" viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="M7 3H3v4m10-4h4v4M3 13v4h4m10-4v4h-4" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg> <span>Fullscreen</span></button>
      {message && <button className="notice" onClick={() => setMessage('')}>{message}</button>}
      <div className="rotate-prompt">
        <svg width="76" height="76" viewBox="0 0 76 76" fill="none" aria-hidden="true"><rect x="10" y="23" width="56" height="31" rx="6" stroke="currentColor" strokeWidth="3"/><path d="M20 16a26 26 0 0 1 39 1m0-9v10h-10M56 62a26 26 0 0 1-39-1m0 9V60h10" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/></svg>
        <h1>Turn your phone</h1>
        <p>Your adventure plays in landscape.</p>
        <button onClick={fullscreen}>Enter fullscreen</button>
      </div>
    </main>
  );
}
