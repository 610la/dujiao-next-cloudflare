import { pbkdf2Sync, randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const remote = process.argv.includes("--remote");
const local = process.argv.includes("--local");

if (remote === local) {
  throw new Error("Choose exactly one target: --local or --remote.");
}

const username = String(process.env.ADMIN_USERNAME || "").trim();
const password = String(process.env.ADMIN_PASSWORD || "");

if (!/^[^\s]{3,64}$/.test(username)) {
  throw new Error("ADMIN_USERNAME must be 3-64 characters without whitespace.");
}
if (password.length < 12) {
  throw new Error("ADMIN_PASSWORD must contain at least 12 characters.");
}

const salt = randomBytes(16).toString("hex");
const iterations = 100_000;
const digest = pbkdf2Sync(password, salt, iterations, 32, "sha256").toString("hex");
const passwordHash = `pbkdf2-sha256$${iterations}$${digest}`;
const sqlString = (value) => `'${String(value).replaceAll("'", "''")}'`;
const sql = [
  "INSERT OR IGNORE INTO authz_roles (role) VALUES ('role:super_admin')",
  "INSERT OR IGNORE INTO authz_policies (role, object, action) VALUES ('role:super_admin', '/*', '*')",
  `INSERT INTO admins (username, password_salt, password_hash, is_super) VALUES (${sqlString(username)}, ${sqlString(salt)}, ${sqlString(passwordHash)}, 1)`,
  `INSERT OR IGNORE INTO authz_admin_roles (admin_id, role) SELECT id, 'role:super_admin' FROM admins WHERE username=${sqlString(username)}`
].join("; ");

const wranglerBin = fileURLToPath(new URL("../node_modules/wrangler/bin/wrangler.js", import.meta.url));
const result = spawnSync(
  process.execPath,
  [wranglerBin, "d1", "execute", "DB", remote ? "--remote" : "--local", "--command", sql],
  { stdio: "inherit", shell: false }
);

if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status || 1);

console.log(`Administrator ${username} created for the ${remote ? "remote" : "local"} database.`);
