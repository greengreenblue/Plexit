using Plexit.RatingStore;
using Toybox.System;

module Plexit {
    class RatingSync extends Deferrable {
        private var d_provider = Plexit.Provider.get();
        private var f_progress;
        private var d_ids = [];
        private var d_idx = 0;
        private var d_rating = null;

        function initialize(progress, done, fail) {
            Deferrable.initialize(method(:sync), done, fail);
            f_progress = progress;
            RatingStore.reload();
            d_ids = RatingStore.getIds();
            d_provider.setFallback(method(:onError));
        }

        function sync() {
            if (d_idx >= d_ids.size()) {
                return Deferrable.complete();
            }

            f_progress.invoke(progress());
            var storage = RatingStore.get(d_ids[d_idx]);
            if (storage == null) {
                d_idx += 1;
                return sync();
            }

            d_rating = new Rating(storage);
            d_provider.rate(
                d_rating.id(),
                d_rating.value(),
                d_rating.ratedAt(),
                method(:onRated)
            );
            return Deferrable.defer();
        }

        function onRated(response) {
            RatingStore.removeIfCurrent(d_rating);
            d_idx += 1;
            sync();
        }

        function onError(error) {
            // Preserve this and all remaining ratings for the next sync. Rating
            // write-back is useful but must not block music downloads.
            System.println("Plex rating sync deferred: " + error);
            Deferrable.complete();
        }

        function progress() {
            if (d_ids.size() == 0) { return 100; }
            return (100 * d_idx) / d_ids.size().toFloat();
        }
    }
}
