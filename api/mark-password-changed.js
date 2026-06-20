const SUPABASE_URL = 'https://zexfyjefmomuaoamwycw.supabase.co';
const SUPABASE_ANON_KEY =
  process.env.SUPABASE_ANON_KEY || 'sb_publishable_rrx6nMypqyFpVYw76O7rhg_zmj4Uj8o';

function json(res, status, body) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(body));
}

async function supabaseFetch(path, { method = 'GET', token, body, serviceRole = false } = {}) {
  const key = serviceRole ? process.env.SUPABASE_SERVICE_ROLE_KEY : SUPABASE_ANON_KEY;
  if (!key) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY no configurada en Vercel.');
  }

  const response = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token || key}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const message = data.msg || data.message || data.error_description || text;
    const error = new Error(message || `Supabase error ${response.status}`);
    error.status = response.status;
    throw error;
  }

  return data;
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return json(res, 405, { error: 'Metodo no permitido.' });
  }

  try {
    const authorization = req.headers.authorization || '';
    const token = authorization.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      return json(res, 401, { error: 'Sesion requerida.' });
    }

    const caller = await supabaseFetch('/auth/v1/user', { token });
    const email = caller.email?.toLowerCase().trim();
    if (!email) {
      return json(res, 401, { error: 'Sesion invalida.' });
    }

    await supabaseFetch('/rest/v1/roles_usuarios?on_conflict=id', {
      method: 'POST',
      serviceRole: true,
      body: {
        id: email,
        rol: 'repartidor',
        deshabilitado: false,
        debeCambiarContrasena: false,
        contrasenaTemporalVisible: '****',
        actualizado: new Date().toISOString(),
      },
    });

    return json(res, 200, { ok: true });
  } catch (error) {
    return json(res, error.status || 500, {
      error: error.message || 'No se pudo marcar la contrasena como cambiada.',
    });
  }
};
