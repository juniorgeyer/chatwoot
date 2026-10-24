import {
  GRID_TABS,
  byArrival,
  isAiResponding,
  isAwaitingReply,
  matchesGridScope,
  matchesGridTab,
  recentMessages,
} from '../helpers';

const message = (id, messageType, extra = {}) => ({
  id,
  message_type: messageType,
  created_at: id,
  content: `message ${id}`,
  ...extra,
});

describe('ConversationGrid helpers', () => {
  describe('byArrival', () => {
    it('keeps cards in arrival order, whatever the last activity', () => {
      const conversations = [
        { id: 7, timestamp: 300 },
        { id: 3, timestamp: 900 },
        { id: 12, timestamp: 100 },
      ];
      expect([...conversations].sort(byArrival).map(c => c.id)).toEqual([
        3, 7, 12,
      ]);
    });
  });

  describe('recentMessages', () => {
    it('returns the last non-activity messages in order', () => {
      const conversation = {
        messages: [message(4, 0), message(1, 0), message(2, 2), message(3, 1)],
      };
      expect(recentMessages(conversation, 2).map(m => m.id)).toEqual([3, 4]);
    });

    it('adds last_non_activity_message when it is missing', () => {
      const conversation = {
        messages: [message(1, 0)],
        last_non_activity_message: message(2, 1),
      };
      expect(recentMessages(conversation).map(m => m.id)).toEqual([1, 2]);
    });
  });

  describe('isAiResponding', () => {
    it('is true for pending conversations or ones assigned to a bot', () => {
      expect(isAiResponding({ status: 'pending' })).toBe(true);
      expect(
        isAiResponding({ status: 'open', meta: { assignee_type: 'AgentBot' } })
      ).toBe(true);
      expect(isAiResponding({ status: 'open', meta: {} })).toBe(false);
    });
  });

  describe('isAwaitingReply', () => {
    it('ignores private notes after the customer message', () => {
      const conversation = {
        status: 'open',
        messages: [message(1, 0), message(2, 1, { private: true })],
      };
      expect(isAwaitingReply(conversation)).toBe(true);
    });

    it('is false once an agent replied', () => {
      const conversation = {
        status: 'open',
        messages: [message(1, 0), message(2, 1)],
      };
      expect(isAwaitingReply(conversation)).toBe(false);
    });

    it('is false while the AI holds the conversation', () => {
      const conversation = { status: 'pending', messages: [message(1, 0)] };
      expect(isAwaitingReply(conversation)).toBe(false);
    });
  });

  describe('matchesGridTab', () => {
    const open = { status: 'open', messages: [message(1, 0)] };
    const pending = { status: 'pending', messages: [message(1, 0)] };
    const resolved = { status: 'resolved', messages: [] };

    it('splits conversations between AI and human tabs', () => {
      expect(matchesGridTab(pending, GRID_TABS.AI)).toBe(true);
      expect(matchesGridTab(pending, GRID_TABS.HUMAN)).toBe(false);
      expect(matchesGridTab(open, GRID_TABS.HUMAN)).toBe(true);
      expect(matchesGridTab(open, GRID_TABS.WAITING)).toBe(true);
    });

    it('leaves resolved conversations out', () => {
      expect(matchesGridTab(resolved, GRID_TABS.ALL)).toBe(false);
    });
  });

  describe('matchesGridScope', () => {
    const conversation = {
      inbox_id: 2,
      labels: ['pix'],
      meta: { team: { id: 5 } },
    };

    it('filters by inbox, label and team', () => {
      expect(matchesGridScope(conversation, { inboxId: '2' })).toBe(true);
      expect(matchesGridScope(conversation, { inboxId: '1' })).toBe(false);
      expect(matchesGridScope(conversation, { label: 'saque' })).toBe(false);
      expect(matchesGridScope(conversation, { teamId: '5' })).toBe(true);
    });
  });
});
