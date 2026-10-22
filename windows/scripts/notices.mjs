import fs from "node:fs/promises";
import path from "node:path";
const lock = JSON.parse(await fs.readFile("package-lock.json", "utf8"));
let output =
  "Markdown Studio Windows — third-party notices\nElectron / Chromium notices are also provided in the application runtime distribution.\n\n";
for (const [folder, record] of Object.entries(lock.packages).sort()) {
  if (!folder || record.dev || record.devOptional) continue;
  const directory = path.resolve(folder);
  let pkg;
  try {
    pkg = JSON.parse(
      await fs.readFile(path.join(directory, "package.json"), "utf8"),
    );
  } catch {
    continue;
  }
  output += `\n${"=".repeat(72)}\n${pkg.name} ${pkg.version}\nLicense: ${pkg.license || "see package notices"}\n`;
  for (const file of (await fs.readdir(directory)).filter((name) =>
    /^(licen[sc]e|copying|notice)(\.|$|-)/i.test(name),
  )) {
    try {
      const text = await fs.readFile(path.join(directory, file), "utf8");
      output += `\n--- ${file} ---\n${text}\n`;
    } catch {}
  }
}
await fs.writeFile("THIRD_PARTY_NOTICES.txt", output);
