-- ============================================================
-- Adiciona FK explícitas para profiles nas tabelas friends e
-- friend_requests, permitindo que o PostgREST resolva os joins
-- usados pelo app Flutter.
-- Execute no SQL Editor do Supabase Dashboard
-- ============================================================

-- friends.friend_id → profiles.id
ALTER TABLE friends
  ADD CONSTRAINT friends_friend_id_fkey
  FOREIGN KEY (friend_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- friend_requests.sender_id → profiles.id
ALTER TABLE friend_requests
  ADD CONSTRAINT friend_requests_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- friend_requests.receiver_id → profiles.id
ALTER TABLE friend_requests
  ADD CONSTRAINT friend_requests_receiver_id_fkey
  FOREIGN KEY (receiver_id) REFERENCES profiles(id) ON DELETE CASCADE;
