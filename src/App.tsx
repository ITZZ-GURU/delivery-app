import { AuthProvider } from '@/lib/auth';
import { CartProvider } from '@/lib/cart';
import { useRouter } from '@/lib/router';
import { Header } from '@/components/Header';
import { Footer } from '@/components/Footer';
import { CartDrawer } from '@/components/CartDrawer';
import { HomePage } from '@/pages/HomePage';
import { MenuPage } from '@/pages/MenuPage';
import { DishDetailPage } from '@/pages/DishDetailPage';
import { SignInPage } from '@/pages/SignInPage';
import { SignUpPage } from '@/pages/SignUpPage';
import { ProfilePage } from '@/pages/ProfilePage';
import { CheckoutPage } from '@/pages/CheckoutPage';
import { OrderConfirmationPage } from '@/pages/OrderConfirmationPage';
import { OrderTrackingPage } from '@/pages/OrderTrackingPage';
import { OrdersPage } from '@/pages/OrdersPage';
import { AdminPage } from '@/pages/AdminPage';

function RouteView() {
  const { route } = useRouter();

  switch (route.name) {
    case 'home': return <HomePage />;
    case 'menu': return <MenuPage />;
    case 'dish': return <DishDetailPage dishId={route.dishId} />;
    case 'signin': return <SignInPage />;
    case 'signup': return <SignUpPage />;
    case 'profile': return <ProfilePage />;
    case 'addresses': return <ProfilePage />;
    case 'checkout': return <CheckoutPage />;
    case 'order-confirmation': return <OrderConfirmationPage orderId={route.orderId} />;
    case 'order-tracking': return <OrderTrackingPage orderId={route.orderId} />;
    case 'orders': return <OrdersPage />;
    case 'admin': return <AdminPage />;
    default: return <HomePage />;
  }
}

function App() {
  return (
    <AuthProvider>
      <CartProvider>
        <div className="flex min-h-screen flex-col">
          <Header />
          <main className="flex-1">
            <RouteView />
          </main>
          <Footer />
          <CartDrawer />
        </div>
      </CartProvider>
    </AuthProvider>
  );
}

export default App;