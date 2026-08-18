-- 20260817000006_state_transitions.sql

-- 1. Create a trigger function to strictly enforce the order state machine
CREATE OR REPLACE FUNCTION private.enforce_order_state_transitions()
RETURNS trigger AS $$
BEGIN
  -- If status hasn't changed, allow the update (e.g., updating notes)
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Terminal states cannot be changed
  IF OLD.status IN ('delivered', 'cancelled') THEN
    RAISE EXCEPTION 'Cannot change status of a % order', OLD.status;
  END IF;

  -- Valid transitions from 'received'
  IF OLD.status = 'received' THEN
    IF NEW.status NOT IN ('preparing', 'cancelled') THEN
      RAISE EXCEPTION 'Invalid transition from received to %', NEW.status;
    END IF;
  
  -- Valid transitions from 'preparing'
  ELSIF OLD.status = 'preparing' THEN
    -- If pickup, it goes straight to delivered. If delivery, out_for_delivery.
    -- (We allow both here to cover both fulfillment types)
    IF NEW.status NOT IN ('out_for_delivery', 'delivered', 'cancelled') THEN
      RAISE EXCEPTION 'Invalid transition from preparing to %', NEW.status;
    END IF;
  
  -- Valid transitions from 'out_for_delivery'
  ELSIF OLD.status = 'out_for_delivery' THEN
    IF NEW.status NOT IN ('delivered', 'cancelled') THEN
      RAISE EXCEPTION 'Invalid transition from out_for_delivery to %', NEW.status;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS enforce_order_state_transitions ON public.orders;
CREATE TRIGGER enforce_order_state_transitions 
  BEFORE UPDATE OF status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION private.enforce_order_state_transitions();


-- 2. Create a secure RPC for customers to cancel their own orders
-- Since customers are read-only on orders table, they need this RPC.
CREATE OR REPLACE FUNCTION private.internal_cancel_order(
  p_order_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_status text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Verify ownership and current status
  SELECT status INTO v_status FROM public.orders WHERE id = p_order_id AND user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found or does not belong to user';
  END IF;

  IF v_status != 'received' THEN
    RAISE EXCEPTION 'Order cannot be cancelled in % state', v_status;
  END IF;

  -- The trigger will allow received -> cancelled
  UPDATE public.orders SET status = 'cancelled' WHERE id = p_order_id;
END;
$$;

REVOKE ALL ON FUNCTION private.internal_cancel_order FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.internal_cancel_order TO authenticated;

-- Expose to API via SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.cancel_order(
  p_order_id uuid
) RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT private.internal_cancel_order(p_order_id);
$$;

REVOKE ALL ON FUNCTION public.cancel_order FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_order TO authenticated;
