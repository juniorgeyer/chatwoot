require 'rails_helper'

# Multiplas fork: a bot message in the agents' queue keeps the contact
# waiting (Message#waiting_for_agent_in_queue?).
RSpec.describe Message do
  describe 'waiting_since with bot messages' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:agent_bot) { create(:agent_bot, account: account) }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:waiting) { 5.minutes.ago.change(usec: 0) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox, status: status, assignee: assignee) }
    let(:assignee) { nil }

    before { conversation.update!(waiting_since: waiting) }

    def bot_message
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent_bot)
    end

    context 'when the conversation is open with no agent (queue)' do
      let(:status) { :open }

      it 'keeps waiting_since' do
        bot_message

        expect(conversation.reload.waiting_since).to eq(waiting)
      end

      it 'keeps the conversation out of the auto resolve scope' do
        bot_message
        conversation.update!(last_activity_at: 20.minutes.ago)

        expect(Conversation.resolvable_not_waiting(10)).not_to include(conversation)
      end
    end

    context 'when the conversation is with the bot (pending)' do
      let(:status) { :pending }

      it 'clears waiting_since as upstream does' do
        bot_message

        expect(conversation.reload.waiting_since).to be_nil
      end
    end

    context 'when an agent is assigned' do
      let(:status) { :open }
      let(:assignee) { agent }

      before { create(:inbox_member, inbox: inbox, user: agent) }

      it 'clears waiting_since as upstream does' do
        bot_message

        expect(conversation.reload.waiting_since).to be_nil
      end
    end

    context 'when an agent replies in the queue' do
      let(:status) { :open }

      it 'clears waiting_since' do
        create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent)

        expect(conversation.reload.waiting_since).to be_nil
      end
    end
  end
end
