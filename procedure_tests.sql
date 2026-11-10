USE little_lemon;
-- Test calls (run AddBooking before Update/Cancel to obtain a valid booking ID).
CALL GetMaxQuantity();
CALL ManageBooking(1);
CALL AddBooking(1, '2026-12-01 18:00:00', 2, 3);
-- Replace 1 below with the booking ID returned by AddBooking if it differs.
CALL UpdateBooking(1, '2026-12-01 19:00:00', 2, 3);
CALL CancelBooking(1);
