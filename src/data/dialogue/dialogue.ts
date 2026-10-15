export interface Condition {
  flag: string;
  is: boolean;
}

export type DialogueAction =
  | { type: "setFlag"; flag: string; value: boolean }
  | { type: "healParty" }
  | { type: "giveItem"; item: string; qty: number };

export interface DialogueNode {
  /** all conditions must hold; first matching node wins; no `when` = fallback */
  when?: Condition[];
  lines: string[];
  actions?: DialogueAction[];
}

export interface Dialogue {
  id: string;
  speaker: string;
  nodes: DialogueNode[];
}

const D = (id: string, speaker: string, nodes: DialogueNode[]): [string, Dialogue] => [id, { id, speaker, nodes }];

export const DIALOGUE: Record<string, Dialogue> = Object.fromEntries([
  D("nurse", "Nurse", [{ lines: ["Welcome to our POKéMON CENTER!", "We heal your POKéMON back to perfect health.", "...", "Thank you for waiting. Your POKéMON are fully healed!", "We hope to see you again!"], actions: [{ type: "healParty" }] }]),
  D("mom", "Mom", [
    { when: [{ flag: "rescuedBirch", is: false }], lines: ["Did you introduce yourself to PROF. BIRCH next door?", "He often works out on Route 101. Be careful in the tall grass!"] },
    { lines: ["Take care out there, dear. Come home if anything happens!"] },
  ]),
  D("rival_mom", "Woman", [{ lines: ["My child is always so full of energy. You two should become good friends!"] }]),
  D("littleroot_man", "Man", [{ lines: ["You can store items on the PC in your room."] }]),
  D("littleroot_boy", "Boy", [{ lines: ["The Professor spends days in his lab, then suddenly heads out to do fieldwork."] }]),
  D("lab_aide", "Aide", [{ lines: ["The Professor is out on fieldwork. He isn't one for desk work."] }]),
  D("route101_boy", "Boy", [{ lines: ["Wild Pokémon jump out at you in tall grass. If you want to catch them, you have to go in and search."] }]),
  D("oldale_girl", "Girl", [{ lines: ["I want to take a rest, so I'm saving my progress."] }]),
  D("oldale_mart", "Mart Employee", [{ lines: ["I work at the Poké Mart. It isn't open in this prototype yet."] }]),
  D("oldale_maniac", "Man", [{ lines: ["I found strange footprints here, but I can't tell whose they are."] }]),
  D("route102_littleboy", "Little Boy", [{ lines: ["I'm not very tall, so I sink right into the tall grass."] }]),
  D("petalburg_woman", "Woman", [{ lines: ["Where has our Wally gone?"] }]),
  D("petalburg_boy", "Boy", [{ lines: ["The water here reflects the sky nicely."] }]),
  D("petalburg_gent", "Gentleman", [{ lines: ["When your party is full, newly caught Pokémon go to storage."] }]),
  D("littleroot_girl", "Neighbor", [
    {
      when: [{ flag: "rescuedBirch", is: false }],
      lines: ["Professor Birch's lab is the house on the right.", "But he's out doing fieldwork. Is he okay?"],
    },
    { lines: ["Tall grass hides wild Pokémon.", "Walk through it and see who shows up!"] },
  ]),
  D("route101_kid", "Youngster", [
    {
      lines: [
        "I saw a Zigzagoon in the grass!",
        "Catch some friends — you can bring up to six into battle formation.",
      ],
    },
  ]),
  D("oldale_nurse", "Nurse", [
    {
      lines: ["Let me heal your Pokémon!", "...", "All healed up. Come back anytime!"],
      actions: [{ type: "healParty" }],
    },
  ]),
  D("route102_catcher", "Bug Catcher", [
    { lines: ["Ralts are super rare around here.", "Weaken it first — the ball works better on a hurt Pokémon!"] },
  ]),
  D("petalburg_guide", "Guide", [
    {
      lines: [
        "Welcome to Petalburg City!",
        "The Gym isn't open yet in this prototype — you've reached the end of the vertical slice.",
        "Keep catching and battling!",
      ],
      actions: [{ type: "setFlag", flag: "talkedPetalburgGuide", value: true }],
    },
  ]),
]);
