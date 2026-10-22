<script setup>
import { computed } from 'vue';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { messageStamp } from 'shared/helpers/timeHelper';
import { isBotMessage } from './helpers';

import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  message: { type: Object, required: true },
});

const isIncoming = computed(
  () => props.message.message_type === MESSAGE_TYPE.INCOMING
);
const isBot = computed(() => isBotMessage(props.message));
const hasAttachments = computed(() => !!props.message.attachments?.length);

const bubbleClass = computed(() => {
  if (props.message.private) {
    return 'self-end bg-n-solid-amber/70 border border-dashed border-n-amber-9 text-n-amber-12';
  }
  if (isIncoming.value) return 'self-start bg-n-slate-4 text-n-slate-12';
  if (isBot.value) return 'self-end bg-n-solid-iris text-n-slate-12';
  return 'self-end bg-n-solid-blue text-n-slate-12';
});

const time = computed(() => messageStamp(props.message.created_at, 'HH:mm'));
</script>

<template>
  <div
    class="flex flex-col max-w-[88%] gap-0.5 px-2.5 py-1.5 rounded-lg text-xs leading-snug"
    :class="bubbleClass"
  >
    <span
      v-if="message.private"
      class="flex items-center gap-1 font-semibold text-xxs uppercase"
    >
      <Icon icon="i-lucide-lock" class="size-3" />
      {{ $t('CONVERSATION_GRID.PRIVATE_NOTE') }}
    </span>
    <div class="flex items-start gap-1.5 min-w-0">
      <Icon
        v-if="isBot && !message.private"
        icon="i-lucide-sparkles"
        class="size-3.5 mt-0.5 shrink-0 text-n-iris-11"
      />
      <p class="line-clamp-2 break-words min-w-0">
        <template v-if="message.content">{{ message.content }}</template>
        <span v-else-if="hasAttachments" class="italic">
          {{ $t('CONVERSATION_GRID.ATTACHMENT') }}
        </span>
      </p>
    </div>
    <span class="self-end text-xxs text-n-slate-11">{{ time }}</span>
  </div>
</template>
