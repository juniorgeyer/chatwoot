<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useConversationGridView } from 'dashboard/composables/useConversationGridView';
import {
  GRID_STATUSES,
  GRID_TABS,
  byArrival,
  matchesGridScope,
  matchesGridSearch,
  matchesGridTab,
  recentMessages,
} from './helpers';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ConversationGridCard from './ConversationGridCard.vue';
import ConversationGridDrawer from './ConversationGridDrawer.vue';

const props = defineProps({
  inboxId: { type: [String, Number], default: 0 },
  label: { type: String, default: '' },
  teamId: { type: String, default: '' },
});

const emit = defineEmits(['drawer']);

// Pages of 25 per status: enough to fill the grid several times over.
const PAGE_SIZE = 25;
const MAX_PAGES = 4;
const MESSAGE_FETCH_CONCURRENCY = 4;

const { t } = useI18n();
const store = useStore();
const { setGridView } = useConversationGridView();

const allConversations = useMapGetter('getAllConversations');
const accountLabels = useMapGetter('labels/getLabels');
const getInbox = useMapGetter('inboxes/getInbox');

const activeTab = ref(GRID_TABS.ALL);
const searchQuery = ref('');
const isLoading = ref(false);

const tabs = computed(() => [
  { key: GRID_TABS.ALL, label: t('CONVERSATION_GRID.TABS.ALL') },
  { key: GRID_TABS.WAITING, label: t('CONVERSATION_GRID.TABS.WAITING') },
  { key: GRID_TABS.AI, label: t('CONVERSATION_GRID.TABS.AI') },
  { key: GRID_TABS.HUMAN, label: t('CONVERSATION_GRID.TABS.HUMAN') },
]);

const scope = computed(() => ({
  inboxId: props.inboxId,
  label: props.label,
  teamId: props.teamId,
}));

const conversations = computed(() =>
  allConversations.value
    .filter(
      conversation =>
        GRID_STATUSES.includes(conversation.status) &&
        matchesGridScope(conversation, scope.value) &&
        matchesGridSearch(conversation, searchQuery.value)
    )
    .sort(byArrival)
);

// A card that leaves (resolved, snoozed) is taken out of the grid flow at its
// current box, so the cards after it slide into place while it fades out.
const pinLeavingCard = el => {
  const { offsetTop, offsetLeft, offsetWidth, offsetHeight } = el;
  Object.assign(el.style, {
    top: `${offsetTop}px`,
    left: `${offsetLeft}px`,
    width: `${offsetWidth}px`,
    height: `${offsetHeight}px`,
  });
};

const tabCounts = computed(() =>
  Object.fromEntries(
    tabs.value.map(({ key }) => [
      key,
      conversations.value.filter(conversation =>
        matchesGridTab(conversation, key)
      ).length,
    ])
  )
);

const visibleConversations = computed(() =>
  conversations.value.filter(conversation =>
    matchesGridTab(conversation, activeTab.value)
  )
);

const loadConversations = async () => {
  isLoading.value = true;
  try {
    await Promise.all(
      GRID_STATUSES.map(async status => {
        for (let page = 1; page <= MAX_PAGES; page += 1) {
          // Pages depend on each other: stop at the first short one.
          // eslint-disable-next-line no-await-in-loop
          const payload = await store.dispatch('fetchGridConversations', {
            status,
            assigneeType: 'all',
            page,
            inboxId: props.inboxId || undefined,
            labels: props.label ? [props.label] : undefined,
            teamId: props.teamId || undefined,
            sortBy: 'last_activity_at_desc',
          });
          if (payload.length < PAGE_SIZE) break;
        }
      })
    );
  } finally {
    isLoading.value = false;
  }
};

// The list API returns only the latest message; fetch the page before it once
// per conversation, so each card can show its last few messages.
const requestedHistory = new Set();
const historyQueue = [];
let activeHistoryRequests = 0;

const drainHistoryQueue = () => {
  while (
    activeHistoryRequests < MESSAGE_FETCH_CONCURRENCY &&
    historyQueue.length
  ) {
    activeHistoryRequests += 1;
    // eslint-disable-next-line no-use-before-define
    fetchHistory(historyQueue.shift());
  }
};

const fetchHistory = conversation =>
  store
    .dispatch('fetchPreviousMessages', {
      conversationId: conversation.id,
      before: conversation.messages?.[0]?.id,
    })
    .catch(() => {})
    .finally(() => {
      activeHistoryRequests -= 1;
      drainHistoryQueue();
    });

watch(
  visibleConversations,
  list => {
    list.forEach(conversation => {
      if (requestedHistory.has(conversation.id)) return;
      if (recentMessages(conversation, 3).length >= 3) return;
      requestedHistory.add(conversation.id);
      historyQueue.push(conversation);
    });
    drainHistoryQueue();
  },
  { immediate: true }
);

watch(scope, loadConversations);
onMounted(loadConversations);

// Multiplas fork: open the conversation in a drawer over the grid.
const isDrawerOpen = ref(false);

const openConversation = async conversation => {
  await store.dispatch('setActiveChat', { data: conversation });
  isDrawerOpen.value = true;
  emit('drawer', true);
};

const closeDrawer = () => {
  isDrawerOpen.value = false;
  store.dispatch('clearSelectedState');
  emit('drawer', false);
};

const inboxName = conversation => getInbox.value(conversation.inbox_id)?.name;
</script>

<template>
  <section class="flex flex-col flex-1 min-w-0 h-full bg-n-background">
    <header
      class="flex flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3 border-b border-n-weak"
    >
      <h1 class="text-lg font-semibold text-n-slate-12">
        {{ $t('CONVERSATION_GRID.TITLE') }}
      </h1>
      <nav class="flex items-center gap-1" role="tablist">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          type="button"
          role="tab"
          :aria-selected="activeTab === tab.key"
          class="flex items-center gap-2 px-3 py-1.5 text-sm rounded-lg transition-colors"
          :class="
            activeTab === tab.key
              ? 'bg-n-alpha-2 text-n-slate-12 font-medium'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
          <span
            class="min-w-5 px-1.5 rounded-full text-xxs font-semibold"
            :class="{
              'bg-n-slate-4 text-n-slate-12': tab.key === GRID_TABS.ALL,
              'bg-n-amber-4 text-n-amber-11': tab.key === GRID_TABS.WAITING,
              'bg-n-iris-4 text-n-iris-11': tab.key === GRID_TABS.AI,
              'bg-n-teal-4 text-n-teal-11': tab.key === GRID_TABS.HUMAN,
            }"
          >
            {{ tabCounts[tab.key] }}
          </span>
        </button>
      </nav>
      <div class="flex items-center gap-2 ms-auto">
        <Spinner v-if="isLoading" class="text-n-slate-10" />
        <div class="relative">
          <span
            class="absolute i-lucide-search size-4 text-n-slate-10 top-2 ltr:left-2.5 rtl:right-2.5"
          />
          <input
            v-model="searchQuery"
            type="search"
            :placeholder="$t('CONVERSATION_GRID.SEARCH_PLACEHOLDER')"
            class="!mb-0 !h-8 w-56 !py-1 ltr:!pl-8 rtl:!pr-8 !text-sm rounded-lg !bg-n-alpha-black2 border !border-n-weak text-n-slate-12"
          />
        </div>
        <Button
          v-tooltip.left="$t('CONVERSATION_GRID.SWITCH_TO_LIST')"
          icon="i-lucide-list"
          slate
          xs
          faded
          @click="setGridView(false)"
        />
      </div>
    </header>

    <div class="flex-1 min-h-0 p-4 overflow-y-auto">
      <TransitionGroup
        v-if="visibleConversations.length"
        tag="div"
        name="grid-card"
        class="relative grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-4"
        @before-leave="pinLeavingCard"
      >
        <ConversationGridCard
          v-for="conversation in visibleConversations"
          :key="conversation.id"
          :conversation="conversation"
          :account-labels="accountLabels"
          :inbox-name="inboxName(conversation)"
          @open="openConversation"
        />
      </TransitionGroup>
      <p
        v-else-if="!isLoading"
        class="py-16 text-sm text-center text-n-slate-11"
      >
        {{ $t('CONVERSATION_GRID.EMPTY') }}
      </p>
    </div>
    <ConversationGridDrawer
      v-if="isDrawerOpen"
      :inbox-id="inboxId"
      @close="closeDrawer"
    />
  </section>
</template>

<style scoped>
/* Cards slide when a neighbour leaves or arrives; the leaving one fades out
   pinned at its old box (pinLeavingCard). */
.grid-card-move,
.grid-card-enter-active,
.grid-card-leave-active {
  transition:
    transform 300ms ease,
    opacity 300ms ease;
}

.grid-card-enter-from,
.grid-card-leave-to {
  opacity: 0;
  transform: scale(0.96);
}

.grid-card-leave-active {
  position: absolute;
}
</style>
