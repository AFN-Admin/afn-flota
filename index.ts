import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async request => {
  try {
    const url = new URL(request.url);
    const body = request.method === 'POST' ? await request.json().catch(() => ({})) : {};
    const paymentId = url.searchParams.get('data.id') || body?.data?.id || body?.id;
    if (!paymentId) return Response.json({ received: true });
    const paymentResponse = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, { headers: { Authorization: `Bearer ${Deno.env.get('MERCADOPAGO_ACCESS_TOKEN')}` } });
    const payment = await paymentResponse.json();
    if (!paymentResponse.ok || payment.status !== 'approved' || !payment.external_reference) return Response.json({ received: true });
    const service = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const companyId = payment.external_reference;
    const { error: companyError } = await service.from('companies').update({ account_status: 'ACTIVE', payment_status: 'PAID', mercadopago_payment_id: String(payment.id) }).eq('id', companyId).eq('account_status', 'PENDING_PAYMENT');
    if (companyError) throw companyError;
    const { error: profileError } = await service.from('profiles').update({ active: true }).eq('company_id', companyId).eq('role', 'COMPANY_ADMIN');
    if (profileError) throw profileError;
    return Response.json({ received: true });
  } catch (error) {
    console.error(error);
    return Response.json({ received: true });
  }
});
