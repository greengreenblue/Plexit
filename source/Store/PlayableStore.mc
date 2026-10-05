using Plexit.Storage;

module Plexit {
    module PlayableStore {

        var d_playableStore = new Store(Storage.PLAYABLE, {});

        function get() {
            return d_playableStore.value();
        }

        function save(playable) {
            d_playableStore.setValue(playable.toStorage());
            return d_playableStore.update();
        }

        function remove() {
            d_playableStore.setValue(null);
            return d_playableStore.update();
        }
    }
}
