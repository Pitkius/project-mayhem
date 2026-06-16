import { assertEnv, env } from './config.js';
import { createClient } from './client.js';

assertEnv();

const client = await createClient();
await client.login(env.token);
