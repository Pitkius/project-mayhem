import { assertEnv, env, tokenDiagnostics } from './config.js';
import { createClient } from './client.js';

assertEnv();

const client = await createClient();
try {
  await client.login(env.token);
} catch (err) {
  const diag = tokenDiagnostics();
  console.error('[MRP] Login nepavyko:', err?.message || err);
  console.error(`[MRP] Token diag: len=${diag.length} parts=${diag.parts} whitespace=${diag.hasWhitespace}`);
  console.error('[MRP] Patikrink API: node scripts/verify-discord-token.js');
  process.exit(1);
}
