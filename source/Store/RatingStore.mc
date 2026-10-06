using Plexit.Storage;
using Toybox.Time;

module Plexit {
    class Rating {
        private var d_id;
        private var d_value;
        private var d_ratedAt;

        function initialize(storage) {
            d_id = storage["id"];
            d_value = storage["value"];
            d_ratedAt = storage["ratedAt"];
            if (d_ratedAt == null) {
                d_ratedAt = Time.now().value();
            }
        }

        function id() { return d_id; }
        function value() { return d_value; }
        function ratedAt() { return d_ratedAt; }

        function toStorage() {
            return {
                "id" => d_id,
                "value" => d_value,
                "ratedAt" => d_ratedAt,
            };
        }
    }

    module RatingStore {
        var d_store = new ObjectStore(Storage.RATINGS_PENDING);

        // ObjectStore keys ratings by track id. Rating the same track again
        // replaces the older pending operation instead of growing the queue.
        function add(rating) { return d_store.save(rating); }
        function get(id) { return d_store.get(id); }
        function getIds() { return d_store.getIds(); }
        function size() { return d_store.getIds().size(); }
        function reload() { d_store.reload(); }
        function reset() { d_store.reset(); }

        function removeIfCurrent(rating) {
            var current = d_store.get(rating.id());
            if (current == null) { return true; }
            // Playback may change a rating while an older request is in flight.
            // Only remove the exact operation acknowledged by Plex.
            if ((current["value"] != rating.value())
                || (current["ratedAt"] != rating.ratedAt())) {
                return false;
            }
            return d_store.remove(rating);
        }
    }
}
