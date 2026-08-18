import { AuthProvider } from '@/features/auth/context/AuthProvider';
import { CartProvider } from '@/features/cart/context/CartProvider';
import { useRouter, navigate } from '@/lib/router';
import { useAuth } from '@/features/auth/hooks/useAuth';
import { Header } from '@/components/common/Header';
import { Footer } from '@/components/common/Footer';
import { CartDrawer } from '@/features/cart/components/CartDrawer';
import { ErrorBoundary } from '@/components/common/ErrorBoundary';
import { HomePage } from '@/pages/HomePage';
import { MenuPage } from '@/features/menu/pages/MenuPage';
import { DishDetailPage } from '@/features/menu/pages/DishDetailPage';
import { SignInPage } from '@/features/auth/pages/SignInPage';
import { SignUpPage } from '@/features/auth/pages/SignUpPage';
import { ProfilePage } from '@/features/profile/pages/ProfilePage';
import { CheckoutPage } from '@/features/checkout/pages/CheckoutPage';
import { OrderConfirmationPage } from '@/features/orders/pages/OrderConfirmationPage';
import { OrderTrackingPage } from '@/features/orders/pages/OrderTrackingPage';
import { OrdersPage } from '@/features/orders/pages/OrdersPage';
import { AdminPage } from '@/features/admin/pages/AdminPage';
import { Loader2 } from 'lucide-react';
import type { ReactNode } from 'react';

function ProtectedRoute({ children, requireVendor }: { children: ReactNode, requireVendor?: boolean }) {
  const { user, role, loading } = useAuth();
  
  if (loading) {
    return <div className="flex min-h-[50vh] items-center justify-center"><Loader2 className="h-8 w-8 animate-spin text-primary-600" /></div>;
  }
  
  if (!user) {
    navigate('/signin');
    return null;
  }
  
  if (requireVendor && role !== 'vendor') {
    navigate('/');
    return null;
  }
  
  return <>{children}</>;
}

function RouteView() {
  const { route } = useRouter();

  switch (route.name) {
    case 'home': return <HomePage />;
    case 'menu': return <MenuPage />;
    case 'dish': return <DishDetailPage dishId={route.dishId} />;
    case 'signin': return <SignInPage />;
    case 'signup': return <SignUpPage />;
    case 'profile': return <ProtectedRoute><ProfilePage /></ProtectedRoute>;
    case 'addresses': return <ProtectedRoute><ProfilePage /></ProtectedRoute>;
    case 'checkout': return <ProtectedRoute><CheckoutPage /></ProtectedRoute>;
    case 'order-confirmation': return <ProtectedRoute><OrderConfirmationPage orderId={route.orderId} /></ProtectedRoute>;
    case 'order-tracking': return <ProtectedRoute><OrderTrackingPage orderId={route.orderId} /></ProtectedRoute>;
    case 'orders': return <ProtectedRoute><OrdersPage /></ProtectedRoute>;
    case 'admin': return <ProtectedRoute requireVendor><AdminPage /></ProtectedRoute>;
    default: return <HomePage />;
  }
}

function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <CartProvider>
          <div className="flex min-h-screen flex-col">
            <Header />
            <main className="flex-1">
              <ErrorBoundary>
                <RouteView />
              </ErrorBoundary>
            </main>
            <Footer />
            <CartDrawer />
          </div>
        </CartProvider>
      </AuthProvider>
    </ErrorBoundary>
  );
}

export default App;