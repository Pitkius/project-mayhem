import { Events } from 'discord.js';
import { handleVerificationReaction } from '../verification/reactions.js';

export default {
  name: Events.MessageReactionAdd,
  async execute(reaction, user) {
    try {
      await handleVerificationReaction(reaction, user, 'add');
    } catch (err) {
      console.error('[Verification] reaction add:', err);
    }
  },
};
