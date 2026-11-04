CREATE TABLE IF NOT EXISTS safety_inboxes (
  id uuid PRIMARY KEY,
  owner_hash text NOT NULL UNIQUE,
  invite_hash text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS safety_messages (
  id uuid PRIMARY KEY,
  inbox_id uuid NOT NULL REFERENCES safety_inboxes(id) ON DELETE CASCADE,
  message text NOT NULL,
  kind text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz
);
CREATE INDEX IF NOT EXISTS safety_messages_inbox ON safety_messages(inbox_id, created_at DESC);
CREATE TABLE IF NOT EXISTS safety_checkins (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES safety_inboxes(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES safety_inboxes(id) ON DELETE CASCADE,
  message text NOT NULL,
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (status IN ('pending', 'safe', 'cancelled', 'alert_stored'))
);
CREATE INDEX IF NOT EXISTS safety_checkins_pending ON safety_checkins(due_at) WHERE status='pending';
