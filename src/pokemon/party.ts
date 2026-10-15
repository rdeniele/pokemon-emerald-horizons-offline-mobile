import type { PokemonInstance } from "./instance";

export const MAX_PARTY = 6;

export interface Collection {
  party: PokemonInstance[];
  storage: PokemonInstance[];
}

/** New catches go to the party while there is room, otherwise storage. */
export function addToCollection(c: Collection, p: PokemonInstance): Collection {
  return c.party.length < MAX_PARTY
    ? { ...c, party: [...c.party, p] }
    : { ...c, storage: [...c.storage, p] };
}

export function reorderParty(c: Collection, from: number, to: number): Collection {
  if (from === to || from < 0 || to < 0 || from >= c.party.length || to >= c.party.length) return c;
  const party = [...c.party];
  const [m] = party.splice(from, 1);
  party.splice(to, 0, m);
  return { ...c, party };
}

/** Swap a party member with a stored Pokémon. */
export function swapWithStorage(c: Collection, partyId: string, storageId: string): Collection {
  const pi = c.party.findIndex((p) => p.id === partyId);
  const si = c.storage.findIndex((p) => p.id === storageId);
  if (pi < 0 || si < 0) return c;
  const party = [...c.party];
  const storage = [...c.storage];
  [party[pi], storage[si]] = [storage[si], party[pi]];
  return { party, storage };
}

export function moveToStorage(c: Collection, id: string): Collection {
  const p = c.party.find((x) => x.id === id);
  if (!p || c.party.length <= 1) return c; // can't empty the party
  return { party: c.party.filter((x) => x.id !== id), storage: [...c.storage, p] };
}

export function moveToParty(c: Collection, id: string): Collection {
  const p = c.storage.find((x) => x.id === id);
  if (!p || c.party.length >= MAX_PARTY) return c;
  return { party: [...c.party, p], storage: c.storage.filter((x) => x.id !== id) };
}

export function release(c: Collection, id: string): Collection {
  if (c.party.length === 1 && c.party[0].id === id) return c;
  return { party: c.party.filter((x) => x.id !== id), storage: c.storage.filter((x) => x.id !== id) };
}

export function rename(c: Collection, id: string, nickname: string): Collection {
  const f = (p: PokemonInstance) => (p.id === id ? { ...p, nickname: nickname.trim() || undefined } : p);
  return { party: c.party.map(f), storage: c.storage.map(f) };
}
