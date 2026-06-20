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
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const message = data.msg || data.message || data.error_description || text;
    const error = new Error(message || `Supabase error ${response.status}`);
    error.status = response.status;
    error.data = data;
    throw error;
  }

  return data;
}

async function findUserByEmail(email) {
  const query = encodeURIComponent(email);
  try {
    const data = await supabaseFetch(`/auth/v1/admin/users?email=${query}`, {
      serviceRole: true,
    });
    const users = Array.isArray(data.users) ? data.users : [];
    return users.find((user) => user.email?.toLowerCase() === email) || null;
  } catch (_) {
    const data = await supabaseFetch('/auth/v1/admin/users?per_page=1000', {
      serviceRole: true,
    });
    const users = Array.isArray(data.users) ? data.users : [];
    return users.find((user) => user.email?.toLowerCase() === email) || null;
  }
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
    const callerEmail = caller.email?.toLowerCase().trim();
    if (!callerEmail) {
      return json(res, 401, { error: 'Sesion invalida.' });
    }

    const roles = await supabaseFetch(
      `/rest/v1/roles_usuarios?id=eq.${encodeURIComponent(callerEmail)}&select=rol,deshabilitado`,
      { serviceRole: true },
    );
    const role = Array.isArray(roles) ? roles[0] : null;
    if (!role || role.rol !== 'admin' || role.deshabilitado === true) {
      return json(res, 403, { error: 'Solo un administrador puede crear usuarios.' });
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const { email, password, name } = body;
    const normalizedEmail = email?.toString().toLowerCase().trim();
    const normalizedName = name?.toString().trim();
    if (!normalizedEmail || !password || password.toString().length < 6) {
      return json(res, 400, { error: 'Email y contrasena valida son requeridos.' });
    }

    const existing = await findUserByEmail(normalizedEmail);
    const payload = {
      email: normalizedEmail,
      password: password.toString(),
      email_confirm: true,
      user_metadata: {
        name: normalizedName || normalizedEmail,
      },
    };

    const user = existing
      ? await supabaseFetch(`/auth/v1/admin/users/${existing.id}`, {
          method: 'PUT',
          serviceRole: true,
          body: payload,
        })
      : await supabaseFetch('/auth/v1/admin/users', {
          method: 'POST',
          serviceRole: true,
          body: payload,
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
      error: error.message || 'No se pudo crear el usuario.',
    });
  }
};
