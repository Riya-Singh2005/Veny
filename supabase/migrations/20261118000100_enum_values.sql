-- New enum values in their own migration: a value added by ALTER TYPE cannot be used
-- in the same transaction that adds it.
alter type public.booking_status add value if not exists 'rejected' after 'pending';
alter type public.notification_type add value if not exists 'booking_rejected';
alter type public.notification_type add value if not exists 'vendor_verified';
alter type public.notification_type add value if not exists 'vendor_rejected';
