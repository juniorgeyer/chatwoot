import { computed, ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

// Shared across the list header and the conversation view, so a toggle in one
// re-renders the other without a reload.
const gridViewByUser = ref({});

const storageKey = userId =>
  `${LOCAL_STORAGE_KEYS.CONVERSATION_GRID_VIEW}::${userId}`;

/**
 * List or grid ("canvas") layout for the conversation screen, remembered per
 * user in localStorage.
 */
export function useConversationGridView() {
  const currentUserId = useMapGetter('getCurrentUserID');

  const isGridView = computed(() => {
    const userId = currentUserId.value;
    return (
      gridViewByUser.value[userId] ??
      LocalStorage.get(storageKey(userId)) === true
    );
  });

  const setGridView = value => {
    const userId = currentUserId.value;
    gridViewByUser.value[userId] = value;
    LocalStorage.set(storageKey(userId), value);
  };

  const toggleGridView = () => setGridView(!isGridView.value);

  return { isGridView, setGridView, toggleGridView };
}
