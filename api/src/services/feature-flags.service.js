const flagPrefix = 'feature-flags:';
const flagNames = ['show_order_wait_time'];
const groups = ['control', 'beta'];

export function createFeatureFlagsService(redis) {
  return {
    async getFlags(group) {
      if (!groups.includes(group)) return null;

      // El grupo de control conserva siempre la interfaz original.
      let enabled = false;
      if (group === 'beta') {
        try {
          enabled = (await redis.get(`${flagPrefix}${flagNames[0]}:${group}`)) === 'true';
        } catch {
          // Si Redis no responde, la funcionalidad queda apagada.
        }
      }
      return { group, flags: { [flagNames[0]]: enabled } };
    },

    async setFlag(flag, group, enabled) {
      if (!flagNames.includes(flag) || group !== 'beta' || typeof enabled !== 'boolean') {
        return false;
      }
      await redis.set(`${flagPrefix}${flag}:${group}`, String(enabled));
      return true;
    },
  };
}
