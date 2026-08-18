import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY;

// These would be injected via CI setup
const CUSTOMER_A_JWT = process.env.CUSTOMER_A_JWT;
const CUSTOMER_B_JWT = process.env.CUSTOMER_B_JWT;
const VENDOR_JWT = process.env.VENDOR_JWT;
const DISH_ID = process.env.DISH_ID;
const CUSTOMER_A_ADDRESS_ID = process.env.CUSTOMER_A_ADDRESS_ID;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error("Missing Supabase credentials");
  process.exit(1);
}

// We will test direct PostgREST calls mimicking the UI
const customerA = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: `Bearer ${CUSTOMER_A_JWT}` } } });
const customerB = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: `Bearer ${CUSTOMER_B_JWT}` } } });
const vendor = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: `Bearer ${VENDOR_JWT}` } } });
const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

let failedTests = 0;

async function assertReject(name: string, promise: Promise<any>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.log(`✅ [PASS] ${name} (Rejected as expected: ${error.message})`);
    } else {
      console.error(`❌ [FAIL] ${name} (Expected rejection but succeeded!)`);
      failedTests++;
    }
  } catch (e: any) {
    console.log(`✅ [PASS] ${name} (Rejected as expected: ${e.message})`);
  }
}

async function runTests() {
  console.log("Running Security Regression Suite...\n");

  // 1. Unauthenticated Order Creation
  await assertReject(
    "Unauthenticated Order Creation",
    anon.rpc('create_order', {
      p_fulfillment_type: 'pickup', p_address_id: null, p_notes: '', p_items: [{ dish_id: DISH_ID, quantity: 1, customizations: [] }]
    })
  );

  // 2. Negative Quantity
  await assertReject(
    "Negative Quantity Exploit",
    customerA.rpc('create_order', {
      p_fulfillment_type: 'pickup', p_address_id: null, p_notes: '', p_items: [{ dish_id: DISH_ID, quantity: -5, customizations: [] }]
    })
  );

  // 3. Excessive Quantity
  await assertReject(
    "Excessive Quantity Exploit",
    customerA.rpc('create_order', {
      p_fulfillment_type: 'pickup', p_address_id: null, p_notes: '', p_items: [{ dish_id: DISH_ID, quantity: 100, customizations: [] }]
    })
  );

  // 4. Forged Customization Price (Note: The new RPC signature ignores price completely, so we just send the label. If we try to send a fake label, it fails.)
  await assertReject(
    "Forged/Invalid Customization",
    customerA.rpc('create_order', {
      p_fulfillment_type: 'pickup', p_address_id: null, p_notes: '', p_items: [{ dish_id: DISH_ID, quantity: 1, customizations: [{ label: 'Fake Customization That Does Not Exist' }] }]
    })
  );

  // 5. Foreign Address (Customer A using Customer B's address... wait we only have A's address here, let's try Customer B using Customer A's address)
  await assertReject(
    "Foreign Address Exploitation",
    customerB.rpc('create_order', {
      p_fulfillment_type: 'delivery', p_address_id: CUSTOMER_A_ADDRESS_ID, p_notes: '', p_items: [{ dish_id: DISH_ID, quantity: 1, customizations: [] }]
    })
  );

  // 6. Cross-User Data Access (Customer B tries to read Customer A's addresses)
  await assertReject(
    "Cross-User Address Read (Horizontal Esc)",
    customerB.from('addresses').select('*').eq('id', CUSTOMER_A_ADDRESS_ID).single()
  );

  // 7. Customers Cannot Update Orders
  await assertReject(
    "Customer Order Update (Direct Table Access)",
    customerA.from('orders').update({ status: 'delivered' }).eq('fulfillment_type', 'pickup')
  );

  // 8. Customers Cannot Delete Orders
  await assertReject(
    "Customer Order Delete",
    customerA.from('orders').delete().neq('id', '00000000-0000-0000-0000-000000000000')
  );

  // 9. Vendor Cannot Delete Orders
  await assertReject(
    "Vendor Order Delete",
    vendor.from('orders').delete().neq('id', '00000000-0000-0000-0000-000000000000')
  );

  // Note: State machine transition tests require an existing order. 
  // In a full CI setup with seeded data, we would fetch a 'delivered' order and attempt to update it to 'preparing' as a vendor.
  
  if (failedTests > 0) {
    console.error(`\n❌ ${failedTests} tests failed.`);
    process.exit(1);
  } else {
    console.log(`\n✅ All security regression tests passed.`);
  }
}

runTests();
