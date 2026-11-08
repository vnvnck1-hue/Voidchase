// 사용자 승인(2026-11-06, squad-voice.html 결과) → assets/audio/void_defense/voice/<영웅>_<skill|hurt>_NN.wav 로 복사
// 하고 vd_audio.gd SFX 에 넣을 줄을 출력한다. 번호는 아래 목록 순서.
//   node apply.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const GAME = path.join(HERE, "..", "..", "assets", "audio", "void_defense", "voice");
export const PICKS = {
  knight_skill: ["knight_lola_skill-01-t1", "knight_lola_skill-02-t1", "knight_lola_skill-04-t1", "knight_aisyah_skill-02-t1", "knight_aisyah_skill-03-t2", "knight_aisyah_skill-05-t2"],
  knight_hurt: ["knight_lola_hurt-02-t1", "knight_lola_hurt-02-t2", "knight_lola_hurt-04-t2", "knight_lola_hurt-05-t2", "knight_aisyah_hurt-01-t1", "knight_aisyah_hurt-02-t2", "knight_aisyah_hurt-03-t1", "knight_aisyah_hurt-04-t2", "knight_aisyah_hurt-05-t2"],
  mage_skill: ["mage_suzu_skill-01-t1", "mage_suzu_skill-01-t2", "mage_suzu_skill-02-t1", "mage_suzu_skill-04-t2", "mage_ayame_skill-01-t2", "mage_ayame_skill-02-t1", "mage_ayame_skill-03-t1"],
  mage_hurt: ["mage_suzu_hurt-01-t1", "mage_suzu_hurt-01-t2", "mage_suzu_hurt-04-t1", "mage_ayame_hurt-01-t1", "mage_ayame_hurt-01-t2", "mage_ayame_hurt-03-t1", "mage_ayame_hurt-04-t1"],
  healer_skill: ["healer_koume_skill-01-t1", "healer_koume_skill-02-t1", "healer_koume_skill-03-t1", "healer_koume_skill-05-t1", "healer_kano_skill-03-t1", "healer_kano_skill-04-t1", "healer_kano_skill-05-t1"],
  healer_hurt: ["healer_koume_hurt-01-t1", "healer_koume_hurt-02-t2", "healer_koume_hurt-03-t1", "healer_koume_hurt-05-t1", "healer_kano_hurt-01-t1", "healer_kano_hurt-02-t1", "healer_kano_hurt-02-t2", "healer_kano_hurt-03-t1", "healer_kano_hurt-05-t2"],
};
for (const [name, ids] of Object.entries(PICKS)) {
  const files = ids.map((id, i) => {
    const f = `${name}_${String(i + 1).padStart(2, "0")}.wav`;
    fs.copyFileSync(path.join(HERE, "edited", id + ".wav"), path.join(GAME, f));
    return `"voice/${f}"`;
  });
  console.log(`\t"voice_${name}": [${files.join(", ")}],`);
}
