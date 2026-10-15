/** Display names for inventory items. */
export const ITEM_NAMES: Record<string, string> = {
  pokeball: "Poké Ball",
  greatball: "Great Ball",
  ultraball: "Ultra Ball",
  potion: "Potion",
  super_potion: "Super Potion",
  hyper_potion: "Hyper Potion",
  max_potion: "Max Potion",
};

export const itemName = (id: string) => ITEM_NAMES[id] ?? id;

/** Winning a trainer battle for the first time pays out a ball upgrade (there is no shop yet). */
export const TRAINER_PRIZE = { item: "greatball", qty: 1 } as const;
