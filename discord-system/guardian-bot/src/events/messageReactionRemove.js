import { Events } from 'discord.js';
import { handleVerificationReaction } from '../verification/reactions.js';

export default {
  name: Events.MessageReactionRemove,
  async execute(reaction, user) {
    try {
      await handleVerificationReaction(reaction, user, 'remove');
    } catch (err) {
      console.error('[Verification] reaction remove:', err);
    }
  },
};
