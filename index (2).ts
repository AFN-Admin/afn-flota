import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const plans: Record<string, { amount: number; name: string }> = {
  CONTROL: { amount: 999, name: 'AFN Flota Control' },
  PROFESIONAL: { amount: 3330, name: 'AFN Flota Profesional' },
};

Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const body = await request.json();
    const required = ['company_name','business_activity','state','address','contact_name','contact_position','email','phone','password','plan_code'];
    if (required.some(key => !String(body[key] ?? '').trim()) || !/^\S+@\S+\.\S+$/.test(body.email) || String(body.password).length < 8) {
      return Response.json({ error: 'Datos de registro inválidos.' }, { status: 400, headers: cors });
    }
    if (!['FREE','CONTROL','PROFESIONAL','EMPRESARIAL'].includes(body.plan_code)) {
      return Response.json({ error: 'Plan inválido.' }, { status: 400, headers: cors });
    }
    const service = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const accountStatus = body.plan_code === 'FREE' ? 'ACTIVE' : body.plan_code === 'EMPRESARIAL' ? 'PENDING_QUOTE' : 'PENDING_PAYMENT';
    const paymentStatus = body.plan_code === 'FREE' ? 'NOT_REQUIRED' : body.plan_code === 'EMPRESARIAL' ? 'QUOTE_PENDING' : 'PENDING';
    const { data: company, error: companyError } = await service.from('companies').insert({
      name: body.company_name, legal_name: body.company_name, business_activity: body.business_activity,
      state: body.state, address: body.address, contact_name: body.contact_name, contact_position: body.contact_position,
      contact_email: body.email.toLowerCase(), contact_phone: body.phone, plan_code: body.plan_code,
      account_status: accountStatus, payment_status: paymentStatus, special_requirements: body.special_requirements || null,
    }).select('id').single();
    if (companyError) throw companyError;
    const { data: created, error: userError } = await service.auth.admin.createUser({ email: body.email.toLowerCase(), password: body.password, email_confirm: true });
    if (userError || !created.user) { await service.from('companies').delete().eq('id', company.id); throw userError || new Error('No fue posible crear el usuario.'); }
    const { error: profileError } = await service.from('profiles').insert({
      id: created.user.id, company_id: company.id, full_name: body.contact_name, email: body.email.toLowerCase(), role: 'COMPANY_ADMIN', active: accountStatus === 'ACTIVE',
    });
    if (profileError) { await service.auth.admin.deleteUser(created.user.id); await service.from('companies').delete().eq('id', company.id); throw profileError; }
    if (body.plan_code === 'FREE') return Response.json({ status: 'ACTIVE' }, { headers: cors });
    if (body.plan_code === 'EMPRESARIAL') return Response.json({ status: 'PENDING_QUOTE' }, { headers: cors });
    const plan = plans[body.plan_code];
    const preference = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST', headers: { Authorization: `Bearer ${Deno.env.get('MERCADOPAGO_ACCESS_TOKEN')}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: [{ title: plan.name, quantity: 1, unit_price: plan.amount, currency_id: 'MXN' }], payer: { email: body.email.toLowerCase() }, external_reference: company.id, notification_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/mercadopago-webhook`, back_urls: { success: Deno.env.get('AFN_SITE_URL'), failure: Deno.env.get('AFN_SITE_URL'), pending: Deno.env.get('AFN_SITE_URL') }, auto_return: 'approved' }),
    });
    const payment = await preference.json();
    if (!preference.ok || !payment.sandbox_init_point) throw new Error(payment.message || 'Mercado Pago no generó el checkout de prueba.');
    await service.from('companies').update({ mercadopago_preference_id: payment.id }).eq('id', company.id);
    return Response.json({ status: 'PENDING_PAYMENT', sandbox_checkout_url: payment.sandbox_init_point }, { headers: cors });
  } catch (error) {
    console.error(error);
    return Response.json({ error: error instanceof Error ? error.message : 'Error inesperado.' }, { status: 400, headers: cors });
  }
});
