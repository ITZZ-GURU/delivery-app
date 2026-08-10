import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables. Please check your .env file.');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

export type Customization = {
  label: string;
  price: number;
};

export type AddressSnapshot = {
  label: string;
  hostel_name: string;
  room_number: string;
  phone: string;
};

export type OrderStatus = 'received' | 'preparing' | 'out_for_delivery' | 'delivered' | 'cancelled';

export type Dish = {
  id: string;
  name: string;
  description: string | null;
  price: number;
  image_url: string | null;
  cuisine: string;
  meal_type: string;
  is_veg: boolean;
  is_available: boolean;
  customizations: Customization[];
  created_at: string;
};

export type Address = {
  id: string;
  user_id: string;
  label: string;
  hostel_name: string;
  room_number: string;
  phone: string;
  created_at: string;
};

export type Order = {
  id: string;
  user_id: string;
  order_number: string;
  fulfillment_type: 'delivery' | 'pickup';
  delivery_address: AddressSnapshot | null;
  items_total: number;
  delivery_fee: number;
  grand_total: number;
  status: OrderStatus;
  payment_collected: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type OrderItem = {
  id: string;
  order_id: string;
  dish_id: string | null;
  dish_name: string;
  dish_price: number;
  quantity: number;
  customizations: Customization[];
  line_total: number;
};

export const MEAL_TYPES = ['Breakfast', 'Lunch', 'Dinner'] as const;
export type MealType = (typeof MEAL_TYPES)[number];

export const ORDER_STATUS_LABELS: Record<OrderStatus, string> = {
  received: 'Order Received',
  preparing: 'Being Prepared',
  out_for_delivery: 'Out for Delivery',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
};

export const ORDER_STATUS_STEPS: OrderStatus[] = ['received', 'preparing', 'out_for_delivery', 'delivered'];

export const DELIVERY_FEE = 20;