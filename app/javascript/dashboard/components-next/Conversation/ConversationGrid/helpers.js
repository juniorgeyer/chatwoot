import {
  CONVERSATION_PRIORITY,
  CONVERSATION_STATUS,
  MESSAGE_TYPE,
} from 'shared/constants/messages';

export const GRID_TABS = {
  ALL: 'all',
  WAITING: 'waiting',
  AI: 'ai',
  HUMAN: 'human',
};

export const GRID_STATUSES = [
  CONVERSATION_STATUS.OPEN,
  CONVERSATION_STATUS.PENDING,
];

const byCreatedAt = (a, b) => a.created_at - b.created_at || a.id - b.id;

// Cards keep their place: the grid is ordered by arrival (conversation id,
// which never changes), not by last activity, so a new message does not
// reshuffle it. New conversations land at the end.
export const byArrival = (a, b) => a.id - b.id;

// The list API seeds `messages` with the latest message only; the grid fetches
// the earlier page, and realtime events append to the same array.
export const recentMessages = (conversation, limit = 3) => {
  const messages = (conversation.messages || []).filter(
    message => message.message_type !== MESSAGE_TYPE.ACTIVITY
  );
  const latest = conversation.last_non_activity_message;
  if (latest && !messages.some(message => message.id === latest.id)) {
    messages.push(latest);
  }
  return messages.sort(byCreatedAt).slice(-limit);
};

export const isBotMessage = message =>
  message.message_type === MESSAGE_TYPE.OUTGOING &&
  (message.sender?.type === 'agent_bot' ||
    message.sender_type === 'AgentBot' ||
    message.sender?.type === 'captain_assistant');

// A conversation is with the AI while the agent bot holds it: `pending` is the
// status Chatwoot keeps while the inbox's agent bot answers.
export const isAiResponding = conversation =>
  conversation.status === CONVERSATION_STATUS.PENDING ||
  conversation.meta?.assignee_type === 'AgentBot';

// Private notes do not answer the customer, so they are skipped.
export const isAwaitingReply = conversation => {
  if (isAiResponding(conversation)) return false;
  const publicMessages = recentMessages(conversation, Infinity).filter(
    message => !message.private
  );
  const lastPublic = publicMessages[publicMessages.length - 1];
  return lastPublic?.message_type === MESSAGE_TYPE.INCOMING;
};

export const isUrgent = conversation =>
  conversation.priority === CONVERSATION_PRIORITY.URGENT;

export const matchesGridTab = (conversation, tab) => {
  if (!GRID_STATUSES.includes(conversation.status)) return false;
  switch (tab) {
    case GRID_TABS.WAITING:
      return isAwaitingReply(conversation);
    case GRID_TABS.AI:
      return isAiResponding(conversation);
    case GRID_TABS.HUMAN:
      return !isAiResponding(conversation);
    default:
      return true;
  }
};

export const matchesGridScope = (conversation, { inboxId, label, teamId }) => {
  if (inboxId && conversation.inbox_id !== Number(inboxId)) return false;
  if (label && !(conversation.labels || []).includes(label)) return false;
  if (teamId && conversation.meta?.team?.id !== Number(teamId)) return false;
  return true;
};

export const matchesGridSearch = (conversation, query) => {
  const term = query.trim().toLowerCase();
  if (!term) return true;
  const {
    name = '',
    email = '',
    phone_number: phone = '',
  } = conversation.meta?.sender || {};
  return [name, email, phone, String(conversation.id)].some(value =>
    (value || '').toLowerCase().includes(term)
  );
};
