-- 1. Add payment_collected column to orders table
ALTER TABLE public.orders ADD COLUMN payment_collected boolean NOT NULL DEFAULT false;

-- 2. Update secure_order_updates trigger function to block customer modifications to payment_collected
CREATE OR REPLACE FUNCTION public.secure_order_updates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- If the user is a vendor, allow any update
  IF private.is_vendor() THEN
    RETURN NEW;
  END IF;

  -- Customers cannot modify core details, totals, or payment status
  IF NEW.items_total != OLD.items_total OR 
     NEW.grand_total != OLD.grand_total OR 
     NEW.delivery_fee != OLD.delivery_fee OR
     NEW.order_number != OLD.order_number OR
     NEW.fulfillment_type != OLD.fulfillment_type OR
     NEW.user_id != OLD.user_id OR
     NEW.delivery_address::text != OLD.delivery_address::text OR
     NEW.payment_collected != OLD.payment_collected THEN
    RAISE EXCEPTION 'Customers cannot modify order core details, totals, or payment status';
  END IF;

  -- Customers can only update notes, OR change status to 'cancelled' (if currently 'received')
  IF NEW.status != OLD.status THEN
    IF OLD.status = 'received' AND NEW.status = 'cancelled' THEN
      -- Allowed
    ELSE
      RAISE EXCEPTION 'Customers can only cancel orders that are still in received status';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
