import { timingSafeEqual } from 'node:crypto';
import { Router } from 'express';

function tokenMatches(provided, expected) {
  if (!provided || !expected) return false;
  const providedBuffer = Buffer.from(provided);
  const expectedBuffer = Buffer.from(expected);
  return providedBuffer.length === expectedBuffer.length
    && timingSafeEqual(providedBuffer, expectedBuffer);
}

export function featureFlagsRoutes(service) {
  const router = Router();

  router.get('/feature-flags', async (req, res) => {
    const group = req.query.group || 'control';
    const result = await service.getFlags(group);
    if (!result) return res.status(400).json({ error: { message: 'group debe ser control o beta.' } });
    res.json(result);
  });

  router.patch('/admin/feature-flags/:flag', async (req, res) => {
    const expectedToken = process.env.FEATURE_FLAGS_ADMIN_TOKEN;
    if (!expectedToken) {
      return res.status(503).json({ error: { message: 'La administración de flags no está configurada.' } });
    }
    const providedToken = req.get('authorization')?.replace(/^Bearer\s+/i, '');
    if (!tokenMatches(providedToken, expectedToken)) {
      return res.status(403).json({ error: { message: 'Credencial administrativa inválida.' } });
    }

    const { group, enabled } = req.body ?? {};
    if (!await service.setFlag(req.params.flag, group, enabled)) {
      return res.status(400).json({ error: { message: 'Se requiere una bandera válida, group beta y enabled booleano.' } });
    }
    res.json({ data: { group, flag: req.params.flag, enabled } });
  });

  return router;
}
