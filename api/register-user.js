const SUPABASE_URL = 'https://zexfyjefmomuaoamwycw.supabase.co';

function json(res, status, body) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(body));
}

async function supabaseFetch(path, { method = 'GET', body } = {}) {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY no configurada en Vercel.');
  }

  const response = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
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

async function findUserByEmail(email) {
  const data = await supabaseFetch('/auth/v1/admin/users?per_page=1000');
  const users = Array.isArray(data.users) ? data.users : [];
  return users.find((user) => user.email?.toLowerCase() === email) || null;
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    return json(res, 405, { error: 'Metodo no permitido.' });
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const email = body.email?.toString().toLowerCase().trim();
    const password = body.password?.toString() || '';
    const name = body.name?.toString().trim() || email;
    const telefono = body.telefono?.toString().trim() || '';
    const region = body.region?.toString().trim() || '';
    const comuna = body.comuna?.toString().trim() || '';
    const direccion = body.direccion?.toString().trim() || '';

    if (!email || !password || password.length < 8) {
      return json(res, 400, { error: 'Email y contrasena valida son requeridos.' });
    }

    const existing = await findUserByEmail(email);
    if (existing) {
      return json(res, 409, { error: 'Ya existe una cuenta con ese correo.' });
    }

    const user = await supabaseFetch('/auth/v1/admin/users', {
      method: 'POST',
      body: {
        email,
        password,
        email_confirm: true,
        user_metadata: { name },
      },
    });

    const now = new Date().toISOString();
    await supabaseFetch('/rest/v1/roles_usuarios?on_conflict=id', {
      method: 'POST',
      body: {
        id: email,
        rol: 'repartidor',
        deshabilitado: false,
        debeCambiarContrasena: false,
        contrasenaTemporalVisible: '****',
        actualizado: now,
      },
    });

    await supabaseFetch('/rest/v1/perfiles_usuarios?on_conflict=id', {
      method: 'POST',
      body: {
        id: email,
        nombre: name,
        email,
        telefono,
        region,
        comuna,
        direccion,
        actualizado: now,
      },
    });

    return json(res, 200, {
      user: {
        id: user.id,
        email: user.email,
        user_metadata: user.user_metadata || {},
      },
    });
  } catch (error) {
    return json(res, error.status || 500, {
      error: error.message || 'No se pudo registrar el usuario.',
    });
  }
};
