using Toybox.Lang;
using Toybox.WatchUi;

module Plexit {
    module I18n {
        function text(resource, arguments) {
            return Lang.format(WatchUi.loadResource(resource), arguments);
        }

        // English shares the few/many form. Slovak and Czech use 1, 2-4, 5+.
        function countText(count, one, few, many) {
            var resource = (count == 1) ? one : (((count >= 2) && (count <= 4)) ? few : many);
            return text(resource, [count]);
        }

        function songs(count) {
            return countText(count, Rez.Strings.SongCount_one,
                Rez.Strings.SongCount_few, Rez.Strings.SongCount_many);
        }

        function songsWaiting(count) {
            return countText(count, Rez.Strings.SongsWaiting_one,
                Rez.Strings.SongsWaiting_few, Rez.Strings.SongsWaiting_many);
        }

        function selectionsWaiting(count) {
            return countText(count, Rez.Strings.SelectionsWaiting_one,
                Rez.Strings.SelectionsWaiting_few, Rez.Strings.SelectionsWaiting_many);
        }

        function ratingsWaiting(count) {
            return countText(count, Rez.Strings.RatingsWaiting_one,
                Rez.Strings.RatingsWaiting_few, Rez.Strings.RatingsWaiting_many);
        }
    }
}
