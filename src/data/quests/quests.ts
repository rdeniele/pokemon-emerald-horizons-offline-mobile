export interface Objective {
  id: string;
  text: string;
  /** objective is complete when this story flag is true */
  flag: string;
}

export interface Quest {
  id: string;
  title: string;
  objectives: Objective[];
  rewards: { item: string; qty: number }[];
  nextQuest?: string;
}

export const QUESTS: Record<string, Quest> = {
  meetProfessor: {
    id: "meetProfessor",
    title: "A Trainer Is Born",
    objectives: [
      { id: "rescue", text: "Walk north onto Route 101 (someone is calling for help!)", flag: "rescuedBirch" },
      { id: "lab", text: "Visit Prof. Birch's lab in Littleroot Town", flag: "visitedLab" },
    ],
    rewards: [{ item: "pokeball", qty: 10 }, { item: "potion", qty: 3 }],
    nextQuest: "reachOldale",
  },
  reachOldale: {
    id: "reachOldale",
    title: "Down Route 101",
    objectives: [{ id: "oldale", text: "Travel north to Oldale Town", flag: "visitedOldale" }],
    rewards: [{ item: "pokeball", qty: 5 }, { item: "potion", qty: 2 }],
    nextQuest: "reachPetalburg",
  },
  reachPetalburg: {
    id: "reachPetalburg",
    title: "To Petalburg",
    objectives: [
      { id: "pb", text: "Cross Route 102 to Petalburg City", flag: "visitedPetalburg" },
      { id: "guide", text: "Speak to the Guide in Petalburg", flag: "talkedPetalburgGuide" },
    ],
    rewards: [
      { item: "greatball", qty: 5 },
      { item: "ultraball", qty: 2 },
    ],
  },
};

export const FIRST_QUEST = "meetProfessor";
