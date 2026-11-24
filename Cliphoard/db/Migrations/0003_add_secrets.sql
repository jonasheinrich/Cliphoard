-- Secret items keep their text only in `ciphertext` (AES-GCM, key in the
-- login keychain); their `text` is empty so searches never match them.
ALTER TABLE items ADD COLUMN is_secret INTEGER NOT NULL DEFAULT 0;
ALTER TABLE items ADD COLUMN ciphertext BLOB;
-- Set once the user marks or unmarks an item, so detection leaves it alone.
ALTER TABLE items ADD COLUMN secret_reviewed INTEGER NOT NULL DEFAULT 0;
