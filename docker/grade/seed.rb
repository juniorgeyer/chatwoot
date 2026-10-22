# Dados de exemplo para testar a visão em grade num Chatwoot local.
#   docker compose -f docker/grade/docker-compose.yaml run --rm \
#     -v "$PWD/docker/grade:/grade" rails bundle exec rails runner /grade/seed.rb
#
# Credenciais só deste ambiente local de teste.
ADMIN_EMAIL = 'admin@grade.localhost'.freeze
ADMIN_PASSWORD = 'Grade#Local2026'.freeze

account = Account.find_or_create_by!(name: '99play')
admin = User.find_or_initialize_by(email: ADMIN_EMAIL)
admin.update!(name: 'Rodolfo Geyer', password: ADMIN_PASSWORD, password_confirmation: ADMIN_PASSWORD,
              confirmed_at: Time.current, type: 'SuperAdmin')
AccountUser.find_or_create_by!(account: account, user: admin) { |au| au.role = :administrator }

agents = ['Harvey', 'Fernanda Paz', 'Rafael Sales'].map do |name|
  email = "#{name.parameterize}@grade.localhost"
  user = User.find_or_initialize_by(email: email)
  user.update!(name: name, password: ADMIN_PASSWORD, password_confirmation: ADMIN_PASSWORD, confirmed_at: Time.current)
  AccountUser.find_or_create_by!(account: account, user: user) { |au| au.role = :agent }
  user
end

def widget_inbox(account, name, url, color)
  account.inboxes.find_by(name: name) ||
    account.inboxes.create!(name: name, channel: Channel::WebWidget.create!(account: account, website_url: url, widget_color: color))
end

play = widget_inbox(account, 'Site 99play', 'https://99play.example', '#1f93ff')
velvet = widget_inbox(account, 'Site Velvet', 'https://velvet.example', '#a855f7')
[play, velvet].each do |inbox|
  (agents + [admin]).each { |user| InboxMember.find_or_create_by!(inbox: inbox, user: user) }
end

bot = account.agent_bots.find_or_create_by!(name: 'Copiloto') { |b| b.outgoing_url = 'http://127.0.0.1:9/copiloto' }

{ 'pagamento' => '#ef4444', 'saque' => '#f59e0b', 'bonus' => '#22c55e', 'acesso-conta' => '#3b82f6',
  'kyc' => '#8b5cf6', 'jogo' => '#14b8a6' }.each do |title, color|
  account.labels.find_or_create_by!(title: title) { |l| l.color = color }
end

# [contato, caixa, status, prioridade, etiqueta, minutos atrás, mensagens]
# Mensagens: [tipo, texto] com tipo :in (cliente), :agent, :bot, :note (nota de atendente), :bot_note
CONVERSATIONS = [
  ['Mariana Silva', play, :open, :urgent, 'pagamento', 2,
   [[:in, 'Meu Pix não caiu, mas o valor saiu da conta.'], [:agent, 'Vou verificar agora. Pode me enviar o comprovante?'],
    [:in, 'Mandei o comprovante por e-mail agora há pouco.']]],
  ['Lucas Costa', play, :open, nil, 'saque', 5,
   [[:in, 'Quanto tempo demora o saque?'], [:agent, 'Saques por Pix caem em até 1 hora.']]],
  ['Fernanda Ribeiro', play, :pending, nil, 'bonus', 6,
   [[:in, 'Quais bônus estão disponíveis hoje?'], [:bot, 'Hoje tem bônus de 100% no primeiro depósito até R$ 500.']]],
  ['Carlos Almeida', velvet, :open, nil, 'kyc', 8,
   [[:in, 'Por que pediram minha selfie de novo?'],
    [:bot_note, 'Sugestão: a selfie anterior ficou desfocada; pedir nova foto com boa luz.']]],
  ['Juliana Prado', play, :open, :high, 'bonus', 11,
   [[:in, 'Conseguem liberar o rollover do bônus?'], [:agent, 'Vou ver com a equipe as condições.'],
    [:note, 'Cliente VIP, avaliar exceção com o supervisor.']]],
  ['Rafael Torres', play, :open, nil, 'acesso-conta', 12,
   [[:in, 'Minha conta foi bloqueada e não consigo entrar.'], [:agent, 'Vou verificar o motivo do bloqueio.'],
    [:in, 'Obrigado, aguardo.']]],
  ['Ana Paula', play, :open, :urgent, 'pagamento', 15,
   [[:in, 'Oi, vocês ainda estão aí?'], [:in, 'Preciso de ajuda urgente com meu depósito!']]],
  ['Bruno Reis', play, :pending, nil, 'jogo', 18,
   [[:in, 'O Aviator travou no meio da rodada.'], [:bot, 'Quando a rodada trava, o valor volta ao saldo em até 5 minutos.']]],
  ['Thiago Alves', play, :pending, nil, 'saque', 21,
   [[:in, 'Qual o valor mínimo de saque?'], [:bot, 'O saque mínimo é de R$ 20 por Pix.'], [:in, 'E o máximo por dia?']]],
  ['Patrícia Coelho', velvet, :open, nil, 'acesso-conta', 24,
   [[:in, 'Vocês têm suporte por telefone?'], [:agent, 'Atendemos por aqui, das 8h à meia-noite.']]],
  ['Diego Martins', velvet, :open, nil, 'jogo', 27,
   [[:in, 'O site está fora do ar para mim.'], [:bot_note, 'Sugestão: pedir para limpar o cache; sem incidente aberto.']]],
  ['Fernanda Lima', play, :open, nil, 'kyc', 32,
   [[:in, 'Enviei meus documentos ontem.'], [:agent, 'Recebemos, a análise sai em até 24 horas.']]],
  ['Gabriel Vieira', play, :open, :urgent, 'saque', 36,
   [[:in, 'Meu saque está pendente há 3 dias.'], [:agent, 'Vou acelerar aqui e te retorno em minutos.']]],
  ['Letícia Nunes', play, :pending, nil, 'bonus', 41,
   [[:in, 'Qual a diferença entre o cashback e o bônus?'], [:bot, 'O cashback devolve 10% das perdas da semana, sem rollover.']]],
  ['Ricardo Campos', velvet, :open, nil, 'pagamento', 47,
   [[:in, 'Posso depositar com cartão?'], [:bot_note, 'Sugestão: só Pix por enquanto; cartão está em homologação.'],
    [:agent, 'No momento só aceitamos Pix.']]],
  ['Sofia Mendes', play, :pending, nil, 'jogo', 52,
   [[:in, 'Tem app para celular?'], [:bot, 'Tem sim! O app está no site, na área Baixar App.']]]
].freeze

CONVERSATIONS.each_with_index do |(name, inbox, status, priority, label, minutes_ago, messages), index|
  email = "#{name.parameterize}@cliente.example"
  contact = account.contacts.find_by(email: email) || account.contacts.create!(name: name, email: email)
  contact_inbox = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) { |ci| ci.source_id = SecureRandom.uuid }
  next if contact_inbox.conversations.exists?

  conversation = account.conversations.create!(inbox: inbox, contact: contact, contact_inbox: contact_inbox)
  conversation.update_labels([label])
  started_at = (minutes_ago + (messages.size * 2)).minutes.ago
  messages.each_with_index do |(kind, content), position|
    attrs = { account: account, inbox: inbox, content: content }
    case kind
    when :in then attrs.merge!(message_type: :incoming, sender: contact)
    when :agent then attrs.merge!(message_type: :outgoing, sender: agents[index % agents.size])
    when :bot then attrs.merge!(message_type: :outgoing, sender: bot)
    when :note then attrs.merge!(message_type: :outgoing, sender: agents[index % agents.size], private: true)
    when :bot_note then attrs.merge!(message_type: :outgoing, sender: bot, private: true)
    end
    message = conversation.messages.create!(attrs)
    message.update_columns(created_at: started_at + (position * 2).minutes)
  end
  # Como no handoff real (bot_handoff!), a conversa aberta sai do robô e vai para um atendente.
  bot_holds = status == :pending
  conversation.update_columns(status: Conversation.statuses[status], priority: priority && Conversation.priorities[priority],
                              last_activity_at: minutes_ago.minutes.ago,
                              assignee_id: bot_holds ? nil : agents[index % agents.size].id,
                              assignee_agent_bot_id: bot_holds ? bot.id : nil, ai_assignee_type: bot_holds ? 'AgentBot' : nil)
end

# O robô entra nas caixas só agora: antes disso, cada mensagem do seed chamaria
# o webhook (inexistente) e o Chatwoot abriria a conversa por erro com o robô.
[play, velvet].each { |inbox| AgentBotInbox.find_or_create_by!(inbox: inbox, agent_bot: bot, account: account) }

puts "Conversas: #{account.conversations.group(:status).count}"
