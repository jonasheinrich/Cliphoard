-- Lets the app filter read one app's items already in date order.
CREATE INDEX items_source_copied_at ON items (source_bundle_id, copied_at);
