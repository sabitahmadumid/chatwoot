require 'rails_helper'

RSpec.describe Integrations::Openai::ProcessorService do
  subject { described_class.new(hook: hook, event: event) }

  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :openai, account: account) }
  let(:expected_headers) { { 'Authorization' => "Bearer #{hook.settings['api_key']}" } }
  let(:openai_response) do
    {
      'choices' => [
        {
          'message' => {
            'content' => 'This is a reply from openai.'
          }
        }
      ]
    }.to_json
  end
  let!(:conversation) { create(:conversation, account: account) }
  let!(:customer_message) { create(:message, account: account, conversation: conversation, message_type: :incoming, content: 'hello agent') }
  let!(:agent_message) { create(:message, account: account, conversation: conversation, message_type: :outgoing, content: 'hello customer') }
  let!(:summary_prompt) do
    if ChatwootApp.enterprise?
      Rails.root.join('enterprise/lib/enterprise/integrations/openai_prompts/summary.txt').read
    else
      'Please summarize the key points from the following conversation between support agents and customer as bullet points for the next ' \
        "support agent looking into the conversation. Reply in the user's language."
    end
  end

  describe '#perform' do
    context 'when event name is rephrase' do
      let(:event) { { 'name' => 'rephrase', 'data' => { 'tone' => 'friendly', 'content' => 'This is a test message' } } }

      it 'returns the rephrased message using the tone in data' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            {
              'role' => 'system',
              'content' => 'You are a helpful support agent. ' \
                           'Please rephrase the following response. ' \
                           'Ensure that the reply should be in user language.'
            },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is reply_suggestion' do
      let(:event) { { 'name' => 'reply_suggestion', 'data' => { 'conversation_display_id' => conversation.display_id } } }

      it 'returns the suggested reply' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { role: 'system',
              content: Rails.root.join('lib/integrations/openai/openai_prompts/reply.txt').read },
            { role: 'user', content: customer_message.content },
            { role: 'assistant', content: agent_message.content }
          ]
        }.to_json

        # Update the stub_request with the correct messages order
        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is summarize' do
      let(:event) { { 'name' => 'summarize', 'data' => { 'conversation_display_id' => conversation.display_id } } }
      let(:conversation_messages) do
        "Customer #{customer_message.sender.name} : #{customer_message.content}\nAgent #{agent_message.sender.name} : #{agent_message.content}\n"
      end

      it 'returns the summarized message' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { 'role' => 'system',
              'content' => summary_prompt },
            { 'role' => 'user', 'content' => conversation_messages }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is label_suggestion with no labels' do
      let(:event) { { 'name' => 'label_suggestion', 'data' => { 'conversation_display_id' => conversation.display_id } } }

      it 'returns nil' do
        result = subject.perform
        expect(result).to be_nil
      end
    end

    context 'when event name is not one that can be processed' do
      let(:event) { { 'name' => 'unknown', 'data' => {} } }

      it 'returns nil' do
        expect(subject.perform).to be_nil
      end
    end

    context 'when event name is fix_spelling_grammar' do
      let(:event) { { 'name' => 'fix_spelling_grammar', 'data' => { 'content' => 'This is a test' } } }

      it 'returns the corrected text' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { 'role' => 'system', 'content' => 'You are a helpful support agent. Please fix the spelling and grammar of the following response. ' \
                                               'Ensure that the reply should be in user language.' },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is shorten' do
      let(:event) { { 'name' => 'shorten', 'data' => { 'content' => 'This is a test' } } }

      it 'returns the shortened text' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { 'role' => 'system', 'content' => 'You are a helpful support agent. Please shorten the following response. ' \
                                               'Ensure that the reply should be in user language.' },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is expand' do
      let(:event) { { 'name' => 'expand', 'data' => { 'content' => 'help you' } } }

      it 'returns the expanded text' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { 'role' => 'system', 'content' => 'You are a helpful support agent. Please expand the following response. ' \
                                               'Ensure that the reply should be in user language.' },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is make_friendly' do
      let(:event) { { 'name' => 'make_friendly', 'data' => { 'content' => 'This is a test' } } }

      it 'returns the friendly text' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { 'role' => 'system', 'content' => 'You are a helpful support agent. Please make the following response more friendly. ' \
                                               'Ensure that the reply should be in user language.' },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is make_formal' do
      let(:event) { { 'name' => 'make_formal', 'data' => { 'content' => 'This is a test' } } }

      it 'returns the formal text' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { 'role' => 'system', 'content' => 'You are a helpful support agent. Please make the following response more formal. ' \
                                               'Ensure that the reply should be in user language.' },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when event name is simplify' do
      let(:event) { { 'name' => 'simplify', 'data' => { 'content' => 'This is a test' } } }

      it 'returns the simplified text' do
        request_body = {
          'model' => '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
          'messages' => [
            { 'role' => 'system', 'content' => 'You are a helpful support agent. Please simplify the following response. ' \
                                               'Ensure that the reply should be in user language.' },
            { 'role' => 'user', 'content' => event['data']['content'] }
          ]
        }.to_json

        stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completions')
          .with(body: request_body, headers: expected_headers)
          .to_return(status: 200, body: openai_response, headers: {})

        result = subject.perform
        expect(result).to eq({ :message => 'This is a reply from openai.' })
      end
    end

    context 'when testing endpoint configuration' do
      let(:event) { { 'name' => 'rephrase', 'data' => { 'content' => 'test message' } } }

      context 'when CAPTAIN_OPEN_AI_ENDPOINT is not configured' do
        it 'uses default OpenAI endpoint' do
          InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.destroy

          stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completion')
            .with(body: anything, headers: expected_headers)
            .to_return(status: 200, body: openai_response, headers: {})

          result = subject.perform
          expect(result).to eq({ :message => 'This is a reply from openai.' })
        end
      end

      context 'when CAPTAIN_OPEN_AI_ENDPOINT is configured' do
        before do
          create(:installation_config, name: 'CAPTAIN_OPEN_AI_ENDPOINT', value: 'https://custom.azure.com/')
        end

        it 'uses custom endpoint' do
          stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completion')
            .with(body: anything, headers: expected_headers)
            .to_return(status: 200, body: openai_response, headers: {})

          result = subject.perform
          expect(result).to eq({ :message => 'This is a reply from openai.' })
        end
      end

      context 'when CAPTAIN_OPEN_AI_ENDPOINT has trailing slash' do
        before do
          create(:installation_config, name: 'CAPTAIN_OPEN_AI_ENDPOINT', value: 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/')
        end

        it 'properly handles trailing slash' do
          stub_request(:post, 'https://api.cloudflare.com/client/v4/accounts/e365f68be929a7213c1350bbb51a4cd3/ai/v1/chat/completion')
            .with(body: anything, headers: expected_headers)
            .to_return(status: 200, body: openai_response, headers: {})

          result = subject.perform
          expect(result).to eq({ :message => 'This is a reply from openai.' })
        end
      end
    end
  end
end
