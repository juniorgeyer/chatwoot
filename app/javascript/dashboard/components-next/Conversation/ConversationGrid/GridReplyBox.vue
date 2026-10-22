<script setup>
import { computed, defineAsyncComponent, ref, useTemplateRef } from 'vue';
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

const message = ref('');
const files = ref([]);
const showEmojiPicker = ref(false);
const messageInput = useTemplateRef('messageInput');
const fileInput = useTemplateRef('fileInput');

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
        @keydown.enter.exact.prevent="send"
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
    <EmojiIconPicker
      v-if="showEmojiPicker"
      v-on-clickaway="() => (showEmojiPicker = false)"
      mode="emoji"
      class="absolute bottom-full z-30 mb-2 ltr:right-0 rtl:left-0"
      @select="addEmoji"
    />
  </div>
</template>
