import type { Customization } from '@/lib/supabase';

export function customizationsKey(c: Customization[]) {
  return c.map((x) => x.label).sort().join(',');
}
