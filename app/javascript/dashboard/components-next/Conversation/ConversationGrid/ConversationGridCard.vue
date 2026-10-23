<script setup>
import { computed, nextTick, onMounted, ref, useTemplateRef, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import { CONVERSATION_PRIORITY } from 'shared/constants/messages';
import {
  isAiResponding,
  isAwaitingReply,
  isUrgent,
  recentMessages,
} from './helpers';

import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import GridMessage from './GridMessage.vue';
import GridReplyBox from './GridReplyBox.vue';

const props = defineProps({
  conversation: { type: Object, required: true },
  accountLabels: { type: Array, required: true },
  inboxName: { type: String, default: '' },
});

const emit = defineEmits(['open']);

const contact = computed(() => props.conversation.meta?.sender || {});

const lastActivityAt = computed(() => {
  const { timestamp } = props.conversation;
  return timestamp ? shortTimestamp(dynamicTime(timestamp)) : '';
});

// Multiplas fork: every loaded message, in a box that scrolls; scrolling to the
// top loads the previous page, as the full conversation does.
const store = useStore();
const messages = computed(() => recentMessages(props.conversation, Infinity));
const scroller = useTemplateRef('scroller');
const isLoadingOlder = ref(false);
const NEAR_EDGE = 24;

const scrollToBottom = () => {
  if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight;
};

const loadOlder = async () => {
  if (isLoadingOlder.value || props.conversation.allMessagesLoaded) return;
  const before = messages.value[0]?.id;
  if (!before) return;
  const box = scroller.value;
  const fromBottom = box.scrollHeight - box.scrollTop;
  isLoadingOlder.value = true;
  try {
    await store.dispatch('fetchPreviousMessages', {
      conversationId: props.conversation.id,
      before,
    });
    await nextTick();
    // Keep the message the agent was reading in place after the prepend.
    box.scrollTop = box.scrollHeight - fromBottom;
  } catch {
    // The card keeps what it has; the drawer shows the full history.
  } finally {
    isLoadingOlder.value = false;
  }
};

const onScroll = () => {
  if (scroller.value?.scrollTop < NEAR_EDGE) loadOlder();
};

onMounted(scrollToBottom);

// New messages stick to the bottom unless the agent scrolled up to read.
watch(
  () => messages.value[messages.value.length - 1]?.id,
  async () => {
    const box = scroller.value;
    const atBottom =
      !box ||
      box.scrollHeight - box.scrollTop - box.clientHeight < NEAR_EDGE * 4;
    await nextTick();
    if (atBottom) scrollToBottom();
  }
);

const urgent = computed(() => isUrgent(props.conversation));
const highPriority = computed(
  () => props.conversation.priority === CONVERSATION_PRIORITY.HIGH
);
const awaiting = computed(() => isAwaitingReply(props.conversation));
const aiResponding = computed(() => isAiResponding(props.conversation));

const accentClass = computed(() => {
  if (urgent.value) return 'border-l-n-ruby-9';
  if (awaiting.value) return 'border-l-n-amber-9';
  if (aiResponding.value) return 'border-l-n-iris-9';
  return 'border-l-n-weak';
});

const label = computed(() => {
  const [title] = props.conversation.labels || [];
  if (!title) return null;
  const accountLabel = props.accountLabels.find(item => item.title === title);
  return { title, color: accountLabel?.color };
});

const extraLabelCount = computed(() =>
  Math.max((props.conversation.labels || []).length - 1, 0)
);

const subject = computed(
  () =>
    props.conversation.additional_attributes?.mail_subject || props.inboxName
);
</script>

<template>
  <article
    class="relative flex flex-col h-[max(15rem,calc((100dvh-7.5rem)/3))] min-w-0 gap-2 p-3 rounded-xl border border-n-weak border-l-4 bg-n-solid-2 cursor-pointer transition-colors hover:bg-n-solid-3"
    :class="accentClass"
    @click="emit('open', conversation)"
  >
    <header class="flex items-start gap-2 min-w-0">
      <Avatar
        :name="contact.name"
        :src="contact.thumbnail"
        :size="32"
        :status="contact.availability_status"
        rounded-full
      />
      <div class="flex flex-col flex-1 min-w-0 gap-1">
        <div class="flex items-center gap-1.5 min-w-0">
          <h4 class="text-sm font-medium truncate text-n-slate-12">
            {{ contact.name }}
          </h4>
          <span
            v-if="conversation.unread_count"
            class="shrink-0 px-1.5 rounded-full bg-n-brand text-xxs font-semibold text-white"
          >
            {{ conversation.unread_count }}
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-1">
          <span
            v-if="urgent || highPriority"
            class="px-1.5 py-0.5 rounded text-xxs font-medium"
            :class="
              urgent ? 'bg-n-ruby-9 text-white' : 'bg-n-amber-3 text-n-amber-11'
            "
          >
            {{
              $t(
                `CONVERSATION.PRIORITY.OPTIONS.${conversation.priority.toUpperCase()}`
              )
            }}
          </span>
          <span
            v-if="awaiting"
            class="px-1.5 py-0.5 rounded text-xxs font-medium bg-n-ruby-3 text-n-ruby-11"
          >
            {{ $t('CONVERSATION_GRID.BADGES.NO_REPLY') }}
          </span>
          <span
            v-if="aiResponding"
            class="flex items-center gap-1 px-1.5 py-0.5 rounded text-xxs font-medium bg-n-iris-3 text-n-iris-11"
          >
            <Icon icon="i-lucide-sparkles" class="size-3" />
            {{ $t('CONVERSATION_GRID.BADGES.AI_RESPONDING') }}
          </span>
        </div>
      </div>
      <span class="shrink-0 text-xs text-n-slate-10">
        {{ lastActivityAt }}
      </span>
    </header>

    <!-- Scrolls inside the card; the top fades so a cut bubble reads as more above. -->
    <div
      ref="scroller"
      class="flex-1 min-h-0 overflow-y-auto overscroll-contain [mask-image:linear-gradient(to_bottom,transparent,black_1.5rem)]"
      @scroll.passive="onScroll"
    >
      <div class="flex flex-col justify-end min-h-full gap-1.5 pt-4">
        <p
          v-if="isLoadingOlder"
          class="m-0 text-xxs text-center text-n-slate-10"
        >
          {{ $t('CONVERSATION_GRID.LOADING_OLDER') }}
        </p>
        <GridMessage
          v-for="message in messages"
          :key="message.id"
          :message="message"
        />
      </div>
    </div>

    <div class="flex items-center gap-1.5 min-w-0 text-xs text-n-slate-11">
      <template v-if="label">
        <span
          class="size-2 shrink-0 rounded-full"
          :style="{ backgroundColor: label.color }"
        />
        <span class="truncate">{{ label.title }}</span>
        <span v-if="extraLabelCount" class="shrink-0 text-n-slate-10">
          {{ `+${extraLabelCount}` }}
        </span>
      </template>
      <template v-else-if="subject">
        <Icon icon="i-lucide-inbox" class="size-3.5 shrink-0" />
        <span class="truncate">{{ subject }}</span>
      </template>
    </div>

    <GridReplyBox :conversation-id="conversation.id" @click.stop />
  </article>
</template>
