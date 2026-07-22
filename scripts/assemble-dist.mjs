import { cp, mkdir, readFile, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";

const root = process.cwd();
const dist = path.join(root, "dist");
const userDist = path.join(root, "apps", "user", "dist");
const adminDist = path.join(root, "apps", "admin", "dist");
const projectConfig = JSON.parse(await readFile(path.join(root, "config", "project.json"), "utf8"));
const adminPath = String(projectConfig.adminPath || "admin-panel")
  .trim()
  .replace(/^\/+|\/+$/g, "")
  .replace(/[^a-zA-Z0-9_-]/g, "");

if (!adminPath) {
  throw new Error("config/project.json adminPath is invalid.");
}

if (!existsSync(userDist)) {
  throw new Error("apps/user/dist is missing. Run npm run build:user first.");
}
if (!existsSync(adminDist)) {
  throw new Error("apps/admin/dist is missing. Run npm run build:admin first.");
}

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
await cp(userDist, dist, { recursive: true });
await mkdir(path.join(dist, adminPath), { recursive: true });
await cp(adminDist, path.join(dist, adminPath), { recursive: true });
