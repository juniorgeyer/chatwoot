require 'rails_helper'

RSpec.describe InboxAssignmentLimit do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:busy_agent) { create(:user, account: account, role: :agent) }
  let(:free_agent) { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, inbox: inbox, user: busy_agent)
    create(:inbox_member, inbox: inbox, user: free_agent)
    create_list(:conversation, 2, account: account, inbox: inbox, assignee: busy_agent, status: :open)
    create(:conversation, account: account, inbox: inbox, assignee: free_agent, status: :open)
    create(:conversation, account: account, inbox: inbox, assignee: free_agent, status: :resolved)
  end

  describe '#user_ids_at_assignment_limit' do
    it 'is empty without a limit' do
      expect(inbox.user_ids_at_assignment_limit).to eq([])
    end

    it 'lists agents whose open conversations reached the limit' do
      inbox.update!(auto_assignment_config: { 'max_assignment_limit' => 2 })

      expect(inbox.user_ids_at_assignment_limit).to eq([busy_agent.id])
    end

    it 'ignores conversations from other inboxes and resolved ones' do
      other_inbox = create(:inbox, account: account)
      create(:conversation, account: account, inbox: other_inbox, assignee: free_agent, status: :open)
      inbox.update!(auto_assignment_config: { 'max_assignment_limit' => 2 })

      expect(inbox.user_ids_at_assignment_limit).not_to include(free_agent.id)
    end
  end

  describe '#member_ids_with_assignment_capacity' do
    it 'drops agents at the limit (legacy assignment)' do
      inbox.update!(auto_assignment_config: { 'max_assignment_limit' => 2 })

      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(free_agent.id)
    end
  end

  describe 'validation' do
    it 'rejects a non-positive limit' do
      inbox.auto_assignment_config = { 'max_assignment_limit' => 0 }

      expect(inbox).not_to be_valid
    end

    it 'accepts a positive limit' do
      inbox.auto_assignment_config = { 'max_assignment_limit' => 10 }

      expect(inbox).to be_valid
    end
  end
end
