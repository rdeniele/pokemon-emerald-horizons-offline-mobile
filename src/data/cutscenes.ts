import { pretText } from "@/data/pret";
import type { ScriptCtx } from "@/game/script";
import { getSpecies } from "@/pokemon/species/species";

export type Scene = (ctx: ScriptCtx) => Promise<void>;

/** Imported Emerald text when available, else our own wording. */
const T = (ctx: ScriptCtx, label: string, fallback: string[], vars?: Record<string, string>) =>
  pretText(label, ctx.session.data.playerName ?? "Trainer", vars) ?? fallback;

/**
 * Story beats, modelled on Emerald's opening: Prof. Birch is chased by a wild Poochyena on Route 101,
 * you grab a Pokémon from his bag and fight it off, then visit his lab.
 */
export const SCENES: Record<string, Scene> = {
  /** Shown after a lost battle, once you are back at the last Pokémon Center. */
  whiteout: async (ctx) => {
    const name = ctx.session.data.playerName;
    await ctx.say("", [`${name} is out of useable POKéMON!`, `${name} whited out!`]);
    const at = ctx.session.data.lastHeal.map;
    const center = /center/i.test(at);
    await ctx.say(center ? "Nurse" : "", center ? ["We've restored your POKéMON to full health.", "We hope to see you again!"] : ["Your POKéMON have recovered while you rested at home."]);
  },

  birchRescue: async (ctx) => {
    const s = ctx.session;
    await ctx.say("???", T(ctx, "Route101_Text_HelpMe", ["H-help me!"]));
    await ctx.say("PROF. BIRCH", T(ctx, "Route101_Text_PleaseHelp", ["Hello! You over there! Please! Help!", "In my BAG! There's a POKé BALL!"]));
    await ctx.pickStarter();
    // the chasing Poochyena; it can't be caught and the fight can't be lost for good (Birch's own Pokémon steps in)
    await ctx.battle([{ speciesId: 261, level: 2 }], { catchable: false });
    await ctx.say(
      "PROF. BIRCH",
      T(ctx, "Route101_Text_YouSavedMe", ["Whew… I was in the tall grass studying wild POKéMON when I was jumped.", "You saved me. Thanks a lot!", "Come by my POKéMON LAB later, okay?"]),
    );
    s.setFlag("talkedBirch", true);
    s.setFlag("rescuedBirch", true);
  },

  labBirch: async (ctx) => {
    const s = ctx.session;
    if (!s.data.flags.visitedLab) {
      const starter = s.data.collection.party[0] ? getSpecies(s.data.collection.party[0].speciesId).name.toUpperCase() : "POKéMON";
      const vars = { STR_VAR_1: starter };
      await ctx.say("PROF. BIRCH", T(ctx, "LittlerootTown_ProfessorBirchsLab_Text_LikeYouToHavePokemon", ["Thanks for earlier! Keep the POKéMON you used."], vars));
      await ctx.say("PROF. BIRCH", T(ctx, "LittlerootTown_ProfessorBirchsLab_Text_WhyNotGiveNicknameToMon", ["Why not give it a nickname? (Menu → Party)"], vars));
      s.setFlag("visitedLab", true);
      return;
    }
    await ctx.say("PROF. BIRCH", ["Oldale Town is just north along ROUTE 101, and PETALBURG CITY lies beyond ROUTE 102.", "Catch plenty of POKéMON and good luck!"]);
  },
};
