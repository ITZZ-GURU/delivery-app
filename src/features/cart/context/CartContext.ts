import { createContext } from 'react';
import type { Customization, Dish } from '@/lib/supabase';

export type CartItem = {
  dish: Dish;
  quantity: number;
  selectedCustomizations: Customization[];
};

export type CartContextValue = {
  items: CartItem[];
  isOpen: boolean;
  openCart: () => void;
  closeCart: () => void;
  addItem: (dish: Dish, quantity: number, customizations: Customization[]) => void;
  updateQuantity: (dishId: string, customizationsKey: string, quantity: number) => void;
  removeItem: (dishId: string, customizationsKey: string) => void;
  clearCart: () => void;
  totalItems: number;
  itemsTotal: number;
  deliveryFee: number;
  grandTotal: number;
};

export const CartContext = createContext<CartContextValue | undefined>(undefined);
