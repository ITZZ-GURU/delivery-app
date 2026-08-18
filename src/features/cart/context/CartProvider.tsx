import { useState, type ReactNode } from 'react';
import type { Customization, Dish } from '@/lib/supabase';
import { DELIVERY_FEE } from '@/lib/supabase';
import { CartContext, type CartItem } from './CartContext';
import { customizationsKey } from '../utils/cartUtils';

export function CartProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]);
  const [isOpen, setIsOpen] = useState(false);

  const openCart = () => setIsOpen(true);
  const closeCart = () => setIsOpen(false);

  const addItem = (dish: Dish, quantity: number, customizations: Customization[]) => {
    // Add quantity bounds as part of Phase 3
    if (quantity <= 0 || quantity > 50) return;
    
    const key = customizationsKey(customizations);
    setItems((prev) => {
      const existing = prev.find(
        (item) => item.dish.id === dish.id && customizationsKey(item.selectedCustomizations) === key,
      );
      if (existing) {
        return prev.map((item) => {
          if (item === existing) {
            const newQuantity = Math.min(item.quantity + quantity, 50);
            return { ...item, quantity: newQuantity };
          }
          return item;
        });
      }
      return [...prev, { dish, quantity, selectedCustomizations: customizations }];
    });
    setIsOpen(true);
  };

  const updateQuantity = (dishId: string, key: string, quantity: number) => {
    if (quantity <= 0) {
      removeItem(dishId, key);
      return;
    }
    const safeQuantity = Math.min(quantity, 50);
    setItems((prev) =>
      prev.map((item) =>
        item.dish.id === dishId && customizationsKey(item.selectedCustomizations) === key
          ? { ...item, quantity: safeQuantity }
          : item,
      ),
    );
  };

  const removeItem = (dishId: string, key: string) => {
    setItems((prev) =>
      prev.filter(
        (item) => !(item.dish.id === dishId && customizationsKey(item.selectedCustomizations) === key),
      ),
    );
  };

  const clearCart = () => setItems([]);

  const totalItems = items.reduce((sum, item) => sum + item.quantity, 0);
  const itemsTotal = items.reduce((sum, item) => {
    const addonTotal = item.selectedCustomizations.reduce((s, c) => s + c.price, 0);
    return sum + (item.dish.price + addonTotal) * item.quantity;
  }, 0);
  const deliveryFee = items.length > 0 ? DELIVERY_FEE : 0;
  const grandTotal = itemsTotal + deliveryFee;

  return (
    <CartContext.Provider
      value={{
        items,
        isOpen,
        openCart,
        closeCart,
        addItem,
        updateQuantity,
        removeItem,
        clearCart,
        totalItems,
        itemsTotal,
        deliveryFee,
        grandTotal,
      }}
    >
      {children}
    </CartContext.Provider>
  );
}
