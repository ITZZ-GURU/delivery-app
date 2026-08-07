import { useEffect, useState } from 'react';
import { supabase, type Order, type Dish, type OrderStatus, ORDER_STATUS_LABELS, ORDER_STATUS_STEPS, formatPrice } from '@/lib/supabase';
import { useAuth } from '@/lib/auth';
import { navigate } from '@/lib/router';
import { Loader2, Plus, Edit2, CheckCircle2 } from 'lucide-react';
import { VegMark } from '@/components/VegMark';

export function AdminPage() {
  const { user, role, loading: authLoading } = useAuth();
  const [activeTab, setActiveTab] = useState<'orders' | 'menu'>('orders');
  
  // Orders State
  const [orders, setOrders] = useState<Order[]>([]);
  const [loadingOrders, setLoadingOrders] = useState(false);
  
  // Menu State
  const [dishes, setDishes] = useState<Dish[]>([]);
  const [loadingMenu, setLoadingMenu] = useState(false);

  useEffect(() => {
    if (authLoading) return;
    if (!user || role !== 'admin') {
      navigate('/');
      return;
    }
  }, [user, role, authLoading]);

  useEffect(() => {
    if (role !== 'admin') return;
    if (activeTab === 'orders') {
      loadOrders();
    } else {
      loadDishes();
    }
  }, [activeTab, role]);

  const loadOrders = async () => {
    setLoadingOrders(true);
    const { data } = await supabase.from('orders').select('*').order('created_at', { ascending: false });
    if (data) setOrders(data);
    setLoadingOrders(false);
  };

  const loadDishes = async () => {
    setLoadingMenu(true);
    const { data } = await supabase.from('dishes').select('*').order('name');
    if (data) setDishes(data);
    setLoadingMenu(false);
  };

  const updateOrderStatus = async (orderId: string, status: OrderStatus) => {
    const { error } = await supabase.from('orders').update({ status }).eq('id', orderId);
    if (!error) {
      setOrders(orders.map(o => o.id === orderId ? { ...o, status } : o));
    }
  };

  const toggleDishAvailability = async (dishId: string, currentStatus: boolean) => {
    const { error } = await supabase.from('dishes').update({ is_available: !currentStatus }).eq('id', dishId);
    if (!error) {
      setDishes(dishes.map(d => d.id === dishId ? { ...d, is_available: !currentStatus } : d));
    }
  };

  if (authLoading || role !== 'admin') {
    return <div className="flex h-screen items-center justify-center"><Loader2 className="h-8 w-8 animate-spin text-primary-600" /></div>;
  }

  return (
    <div className="animate-fade-in container-app py-8">
      <div className="flex items-center justify-between mb-8">
        <h1 className="font-serif text-3xl font-bold text-charcoal-900">Admin Dashboard</h1>
      </div>

      <div className="flex gap-4 border-b border-cream-200 mb-6">
        <button
          onClick={() => setActiveTab('orders')}
          className={`pb-3 px-2 text-sm font-semibold transition-all ${activeTab === 'orders' ? 'border-b-2 border-primary-600 text-primary-700' : 'text-charcoal-500 hover:text-charcoal-800'}`}
        >
          Manage Orders
        </button>
        <button
          onClick={() => setActiveTab('menu')}
          className={`pb-3 px-2 text-sm font-semibold transition-all ${activeTab === 'menu' ? 'border-b-2 border-primary-600 text-primary-700' : 'text-charcoal-500 hover:text-charcoal-800'}`}
        >
          Manage Menu
        </button>
      </div>

      {activeTab === 'orders' && (
        <div>
          {loadingOrders ? (
            <div className="flex justify-center py-10"><Loader2 className="h-6 w-6 animate-spin text-primary-600" /></div>
          ) : orders.length === 0 ? (
            <p className="text-center text-charcoal-500 py-10">No orders found.</p>
          ) : (
            <div className="space-y-4">
              {orders.map(order => (
                <div key={order.id} className="card p-5 border-l-4 border-l-primary-600">
                  <div className="flex flex-col md:flex-row justify-between md:items-center gap-4">
                    <div>
                      <h3 className="font-bold text-lg text-charcoal-900">Order #{order.order_number}</h3>
                      <p className="text-sm text-charcoal-500 mt-1">Total: {formatPrice(order.grand_total)} • {order.fulfillment_type}</p>
                      {order.fulfillment_type === 'delivery' && order.delivery_address && (
                        <p className="text-xs text-charcoal-400 mt-1">
                          Delivery to: {order.delivery_address.hostel_name}, Room {order.delivery_address.room_number} ({order.delivery_address.phone})
                        </p>
                      )}
                    </div>
                    <div className="flex items-center gap-3">
                      <select
                        value={order.status}
                        onChange={(e) => updateOrderStatus(order.id, e.target.value as OrderStatus)}
                        className="input text-sm font-medium"
                      >
                        {Object.entries(ORDER_STATUS_LABELS).map(([val, label]) => (
                          <option key={val} value={val}>{label}</option>
                        ))}
                      </select>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {activeTab === 'menu' && (
        <div>
          <div className="flex justify-end mb-4">
            <button className="btn-primary flex items-center gap-2 text-sm">
              <Plus className="h-4 w-4" /> Add Dish (Coming Soon)
            </button>
          </div>
          {loadingMenu ? (
            <div className="flex justify-center py-10"><Loader2 className="h-6 w-6 animate-spin text-primary-600" /></div>
          ) : dishes.length === 0 ? (
            <p className="text-center text-charcoal-500 py-10">No dishes found in the database.</p>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
              {dishes.map(dish => (
                <div key={dish.id} className={`card p-4 flex gap-4 ${dish.is_available ? '' : 'opacity-60 grayscale'}`}>
                  {dish.image_url && (
                    <img src={dish.image_url} alt={dish.name} className="h-20 w-20 rounded-lg object-cover" />
                  )}
                  <div className="flex-1">
                    <div className="flex items-start justify-between">
                      <h3 className="font-semibold text-charcoal-900">{dish.name}</h3>
                      <VegMark isVeg={dish.is_veg} />
                    </div>
                    <p className="font-bold text-primary-700 text-sm mt-1">{formatPrice(dish.price)}</p>
                    <div className="flex justify-between items-center mt-3">
                      <span className={`text-xs font-medium px-2 py-1 rounded-full ${dish.is_available ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                        {dish.is_available ? 'Available' : 'Unavailable'}
                      </span>
                      <button
                        onClick={() => toggleDishAvailability(dish.id, dish.is_available)}
                        className="text-xs font-semibold text-primary-600 hover:underline"
                      >
                        Toggle
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
