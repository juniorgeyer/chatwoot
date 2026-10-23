<script setup>
import { computed, defineAsyncComponent, onMounted, ref, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { createPendingMessage } from 'dashboard/helper/commons';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: { type: Number, required: true },
});

const EmojiIconPicker = defineAsyncComponent(
  () =>
    import('dashboard/components-next/emoji-icon-picker/EmojiIconPicker.vue')
);

const { t } = useI18n();
const store = useStore();
const currentUser = useMapGetter('getCurrentUser');
const cannedResponses = useMapGetter('getCannedResponses');

const message = ref('');
const files = ref([]);
const showEmojiPicker = ref(false);
const messageInput = useTemplateRef('messageInput');
const fileInput = useTemplateRef('fileInput');

// Multiplas fork: "/" + short code picks a canned response, as in the editor.
const cannedQuery = computed(() => {
  const match = message.value.match(/^\/(\S*)$/);
  return match ? match[1].toLowerCase() : null;
});
const cannedMatches = computed(() => {
  if (cannedQuery.value === null) return [];
  return cannedResponses.value
    .filter(
      ({ short_code: code = '', content = '' }) =>
        code.toLowerCase().includes(cannedQuery.value) ||
        content.toLowerCase().includes(cannedQuery.value)
    )
    .slice(0, 6);
});
const cannedIndex = ref(0);
const pickCanned = canned => {
  message.value = canned.content;
  cannedIndex.value = 0;
  messageInput.value?.focus();
};
const moveCanned = step => {
  const total = cannedMatches.value.length;
  if (!total) return;
  cannedIndex.value = (cannedIndex.value + step + total) % total;
};
const onEnter = () => {
  const canned = cannedMatches.value[cannedIndex.value];
  if (canned) pickCanned(canned);
  else send();
};
onMounted(() => {
  if (!cannedResponses.value.length) store.dispatch('getCannedResponse');
});

const canSend = computed(
  () => !!message.value.trim() || files.value.length > 0
);

const onFilesSelected = event => {
  files.value = [...files.value, ...event.target.files];
  event.target.value = '';
};

const removeFile = index => {
  files.value = files.value.filter((_, i) => i !== index);
};

const addEmoji = ({ value }) => {
  message.value += value;
  showEmojiPicker.value = false;
  messageInput.value?.focus();
};

const send = async () => {
  if (!canSend.value) return;
  const { id, name, avatar_url: thumbnail } = currentUser.value;
  const payload = {
    conversationId: props.conversationId,
    message: message.value.trim(),
    private: false,
    sender: { id, name, thumbnail },
  };
  if (files.value.length) payload.files = files.value;

  message.value = '';
  files.value = [];
  try {
    // Awaiting the send itself (not createPendingMessageAndSend) surfaces errors.
    await store.dispatch('sendMessageWithData', createPendingMessage(payload));
  } catch (error) {
    useAlert(error?.response?.data?.error || t('CONVERSATION.MESSAGE_ERROR'));
  }
};
</script>

<template>
  <div class="relative flex flex-col gap-1">
    <div v-if="files.length" class="flex flex-wrap gap-1">
      <span
        v-for="(file, index) in files"
        :key="`${file.name}-${index}`"
        class="flex items-center gap-1 px-1.5 py-0.5 rounded-md bg-n-alpha-2 text-xxs text-n-slate-12 max-w-full"
      >
        <span class="truncate">{{ file.name }}</span>
        <button
          type="button"
          class="i-lucide-x size-3 shrink-0 text-n-slate-11"
          :aria-label="$t('CONVERSATION_GRID.REMOVE_ATTACHMENT')"
          @click="removeFile(index)"
        />
      </span>
    </div>
    <div class="flex items-center gap-1">
      <input
        ref="messageInput"
        v-model="message"
        type="text"
        :placeholder="$t('CONVERSATION_GRID.REPLY_PLACEHOLDER')"
        class="flex-1 min-w-0 !mb-0 !h-8 !px-2.5 !py-1 !text-xs rounded-lg !bg-n-alpha-black2 border !border-n-weak text-n-slate-12 placeholder:text-n-slate-10"
        @keydown.enter.exact.prevent="onEnter"
        @keydown.down.prevent="moveCanned(1)"
        @keydown.up.prevent="moveCanned(-1)"
        @input="cannedIndex = 0"
      />
      <input
        ref="fileInput"
        type="file"
        multiple
        class="hidden"
        @change="onFilesSelected"
      />
      <Button
        v-tooltip.top="$t('CONVERSATION_GRID.ATTACH')"
        icon="i-lucide-paperclip"
        slate
        ghost
        xs
        @click="fileInput.click()"
      />
      <Button
        v-tooltip.top="$t('CONVERSATION_GRID.EMOJI')"
        icon="i-lucide-smile"
        slate
        ghost
        xs
        @click="showEmojiPicker = !showEmojiPicker"
      />
      <Button
        v-tooltip.top="$t('CONVERSATION_GRID.SEND')"
        icon="i-lucide-send-horizontal"
        :disabled="!canSend"
        xs
        ghost
        @click="send"
      />
    </div>
    <ul
      v-if="cannedMatches.length"
      class="absolute bottom-full z-30 w-full p-1 mb-2 overflow-y-auto list-none rounded-lg shadow-lg max-h-56 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak"
    >
      <li v-for="(canned, index) in cannedMatches" :key="canned.id">
        <button
          type="button"
          class="flex flex-col w-full gap-0.5 px-2 py-1.5 text-start rounded-md"
          :class="index === cannedIndex ? 'bg-n-alpha-2' : 'hover:bg-n-alpha-1'"
          @mousedown.prevent="pickCanned(canned)"
        >
          <span class="text-xs font-medium text-n-slate-12">
            /{{ canned.short_code }}
          </span>
          <span class="text-xxs truncate text-n-slate-11">
            {{ canned.content }}
          </span>
        </button>
      </li>
    </ul>
    <EmojiIconPicker
      v-if="showEmojiPicker"
      v-on-clickaway="() => (showEmojiPicker = false)"
      mode="emoji"
      class="absolute bottom-full z-30 mb-2 ltr:right-0 rtl:left-0"
      @select="addEmoji"
    />
  </div>
</template>
