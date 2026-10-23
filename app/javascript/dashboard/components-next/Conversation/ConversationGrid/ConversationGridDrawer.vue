<script setup>
// Multiplas fork: the full conversation (messages, reply editor with canned
// responses, contact panel with macros) in a drawer over the grid, so agents
// keep the grid in view instead of navigating away.
import { onBeforeUnmount, onMounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';

import Button from 'dashboard/components-next/button/Button.vue';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';
import ConversationBox from 'dashboard/components/widgets/conversation/ConversationBox.vue';
import ConversationSidebar from 'dashboard/components/widgets/conversation/ConversationSidebar.vue';

defineProps({
  inboxId: { type: [String, Number], default: 0 },
});

const emit = defineEmits(['close']);

const currentChat = useMapGetter('getSelectedChat');
const { uiSettings } = useUISettings();

const close = () => emit('close');

// Escape closes the drawer unless a menu or modal inside it took the key.
const onKeydown = event => {
  if (event.key === 'Escape' && !event.defaultPrevented) close();
};

onMounted(() => window.addEventListener('keydown', onKeydown));
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown));
</script>

<template>
  <div class="fixed inset-0 z-50 flex">
    <div class="flex-1 bg-n-alpha-black1 backdrop-blur-[1px]" @click="close" />
    <aside
      class="relative flex w-3/4 h-full min-w-0 shadow-xl bg-n-background border-s border-n-weak"
      role="dialog"
      aria-modal="true"
    >
      <Button
        v-tooltip.left="$t('CONVERSATION_GRID.CLOSE_DRAWER')"
        icon="i-lucide-x"
        slate
        xs
        faded
        class="absolute z-10 top-3 -start-10"
        @click="close"
      />
      <ConversationBox
        v-if="currentChat.id"
        :inbox-id="inboxId"
        :is-on-expanded-layout="false"
      >
        <SidepanelSwitch />
      </ConversationBox>
      <ConversationSidebar
        v-if="currentChat.id && uiSettings.is_contact_sidebar_open"
        :current-chat="currentChat"
      />
    </aside>
  </div>
</template>
