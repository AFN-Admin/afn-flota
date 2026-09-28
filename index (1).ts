import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const limits: Record<string, { operators: number; assets: number }> = {
  FREE: { operators: 6, assets: 2 },
  CONTROL: { operators: 36, assets: 12 },
  PROFESIONAL: { operators: 150, assets: 50 },
  EMPRESARIAL: { operators: Number.POSITIVE_INFINITY, assets: Number.POSITIVE_INFINITY },
};

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
    if (!token) return Response.json({ error: 'Sesión no autorizada.' }, { status: 401, headers: cors });
    const service = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: auth, error: authError } = await service.auth.getUser(token);
    if (authError || !auth.user) return Response.json({ error: 'Sesión no autorizada.' }, { status: 401, headers: cors });
    const { data: admin } = await service.from('profiles').select('company_id,role,active').eq('id', auth.user.id).single();
    if (!admin?.active || admin.role !== 'COMPANY_ADMIN' || !admin.company_id) {
      return Response.json({ error: 'Solo un administrador activo de empresa puede crear operadores.' }, { status: 403, headers: cors });
    }
    const { data: company } = await service
      .from('companies')
      .select('plan_code')
      .eq('id', admin.company_id)
      .single();
    const planCode = company?.plan_code || 'FREE';
    const plan = limits[planCode] || limits.FREE;
    const { count: operatorCount, error: countError } = await service
      .from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('company_id', admin.company_id)
      .eq('role', 'OPERATOR')
      .eq('active', true);
    if (countError) throw countError;
    if (operatorCount !== null && operatorCount >= plan.operators) {
      return Response.json(
        { error: `Tu plan ${planCode} admite hasta ${plan.operators} operadores activos.` },
        { status: 409, headers: cors },
      );
    }
    const body = await request.json();
    const name = String(body.name || '').trim(), email = String(body.email || '').trim().toLowerCase(), password = String(body.password || '');
    if (!name || !/^\S+@\S+\.\S+$/.test(email) || password.length < 8) {
      return Response.json({ error: 'Captura nombre, correo válido y contraseña de al menos 8 caracteres.' }, { status: 400, headers: cors });
    }
    const { data: created, error: createError } = await service.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { full_name: name } });
    if (createError || !created.user) throw createError || new Error('No fue posible crear el operador.');
    const { error: profileError } = await service.from('profiles').insert({
      id: created.user.id, company_id: admin.company_id, full_name: name, email, role: 'OPERATOR', active: true,
    });
    if (profileError) {
      await service.auth.admin.deleteUser(created.user.id);
      throw profileError;
    }
    return Response.json({ ok: true, operator_id: created.user.id }, { headers: cors });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Error inesperado.' }, { status: 400, headers: cors });
  }
});
