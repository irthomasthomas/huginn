require 'rails_helper'

describe Agents::GoogleCalendarPublishAgent do
  let(:valid_params) do
    {
      'expected_update_period_in_days' => '10',
      'calendar_id' => calendar_id,
      'google' => {
        'key_file' => File.dirname(__FILE__) + '/../../data_fixtures/private.key',
        'key_secret' => 'notasecret',
        'service_account_email' => '1029936966326-ncjd7776pcspc98hsg82gsb56t3217ef@developer.gserviceaccount.com'
      }
    }
  end

  let(:agent) do
    _agent = Agents::GoogleCalendarPublishAgent.new(name: 'somename', options: valid_params)
    _agent.user = users(:jane)
    _agent.save!
    _agent
  end

  describe '#receive' do
    let(:message) do
      {
        'visibility' => 'default',
        'summary' => 'Awesome event',
        'description' => 'An example event with text. Pro tip: DateTimes are in RFC3339',
        'end' => {
          'date_time' => '2014-10-02T11:00:00-05:00'
        },
        'start' => {
          'date_time' => '2014-10-02T10:00:00-05:00'
        }
      }
    end

    let(:event) do
      _event = Event.new
      _event.agent = agents(:bob_manual_event_agent)
      _event.payload = { 'message' => message }
      _event.save!
      _event
    end

    let(:calendar_id) { 'sqv39gj35tc837gdns1g4d81cg@group.calendar.google.com' }

    let(:response_hash) do
      { 'kind' => 'calendar#event',
        'etag' => '"2908684044040000"',
        'id' => 'baz',
        'status' => 'confirmed',
        'html_link' =>
          'https://calendar.google.com/calendar/event?eid=foobar',
        'created' => '2016-02-01T15:53:41.000Z',
        'updated' => '2016-02-01T15:53:42.020Z',
        'summary' => 'Awesome event',
        'description' =>
          'An example event with text. Pro tip: DateTimes are in RFC3339',
        'creator' =>
          { 'email' =>
            'blah-foobar@developer.gserviceaccount.com' },
        'organizer' =>
          { 'email' => calendar_id,
            'display_name' => 'Huginn Location Log',
            'self' => true },
        'start' => { 'date_time' => '2014-10-03T00:30:00+09:30' },
        'end' => { 'date_time' => '2014-10-03T01:30:00+09:30' },
        'i_cal_uid' => 'blah@google.com',
        'sequence' => 0,
        'reminders' => { 'use_default' => true } }
    end

    def setup_mock!
      fake_interface = double('fake_interface')
      expect(GoogleCalendar).to receive(:new).with(agent.interpolate_options(agent.options), Rails.logger) {
                                  fake_interface
                                }
      expect(fake_interface).to receive(:publish_as).with(calendar_id, message) { response_hash }
      expect(fake_interface).to receive(:cleanup!)
    end

    describe 'when the calendar_id is in the options' do
      it 'should publish any payload it receives' do
        setup_mock!

        expect do
          agent.receive([event])
        end.to change { agent.events.count }.by(1)

        expect(agent.events.last.payload).to eq({ 'success' => true, 'published_calendar_event' => response_hash,
                                                  'agent_id' => event.agent_id, 'event_id' => event.id })
      end
    end

    describe 'with Liquid templating' do
      it 'should allow Liquid in the calendar_id' do
        setup_mock!

        agent.options['calendar_id'] = '{{ cal_id }}'
        agent.save!

        event.payload['cal_id'] = calendar_id
        event.save!

        agent.receive([event])

        expect(agent.events.count).to eq(1)
        expect(agent.events.last.payload).to eq({ 'success' => true, 'published_calendar_event' => response_hash,
                                                  'agent_id' => event.agent_id, 'event_id' => event.id })
      end

      it 'should allow Liquid in the key' do
        agent.options['google'].delete('key_file')
        agent.options['google']['key'] = '{% credential google_key %}'
        agent.save!

        users(:jane).user_credentials.create! credential_name: 'google_key', credential_value: 'something'

        agent.reload

        setup_mock!

        agent.receive([event])

        expect(agent.events.count).to eq(1)
      end
    end
  end

  describe '#receive old style event' do
    let(:event) do
      _event = Event.new
      _event.agent = agents(:bob_manual_event_agent)
      _event.payload = { 'message' => {
        'visibility' => 'default',
        'summary' => 'Awesome event',
        'description' => 'An example event with text. Pro tip: DateTimes are in RFC3339',
        'end' => {
          'dateTime' => '2014-10-02T11:00:00-05:00'
        },
        'start' => {
          'dateTime' => '2014-10-02T10:00:00-05:00'
        }
      } }
      _event.save!
      _event
    end

    let(:calendar_id) { 'sqv39gj35tc837gdns1g4d81cg@group.calendar.google.com' }
    let(:message) do
      {
        'visibility' => 'default',
        'summary' => 'Awesome event',
        'description' => 'An example event with text. Pro tip: DateTimes are in RFC3339',
        'end' => {
          'date_time' => '2014-10-02T11:00:00-05:00'
        },
        'start' => {
          'date_time' => '2014-10-02T10:00:00-05:00'
        }
      }
    end

    let(:response_hash) do
      { 'kind' => 'calendar#event',
        'etag' => '"2908684044040000"',
        'id' => 'baz',
        'status' => 'confirmed',
        'html_link' =>
          'https://calendar.google.com/calendar/event?eid=foobar',
        'created' => '2016-02-01T15:53:41.000Z',
        'updated' => '2016-02-01T15:53:42.020Z',
        'summary' => 'Awesome event',
        'description' =>
          'An example event with text. Pro tip: DateTimes are in RFC3339',
        'creator' =>
          { 'email' =>
            'blah-foobar@developer.gserviceaccount.com' },
        'organizer' =>
          { 'email' => calendar_id,
            'display_name' => 'Huginn Location Log',
            'self' => true },
        'start' => { 'date_time' => '2014-10-03T00:30:00+09:30' },
        'end' => { 'date_time' => '2014-10-03T01:30:00+09:30' },
        'i_cal_uid' => 'blah@google.com',
        'sequence' => 0,
        'reminders' => { 'use_default' => true } }
    end

    def setup_mock!
      fake_interface = double('fake_interface')
      expect(GoogleCalendar).to receive(:new).with(agent.interpolate_options(agent.options), Rails.logger) {
                                  fake_interface
                                }
      allow(fake_interface).to receive(:publish_as).with(calendar_id, message) { response_hash }
      expect(fake_interface).to receive(:cleanup!)
    end

    describe 'when the calendar_id is in the options' do
      it 'should publish old style payload it receives' do
        setup_mock!

        expect do
          agent.receive([event])
        end.to change { agent.events.count }.by(1)

        expect(agent.events.last.payload).to eq({ 'success' => true, 'published_calendar_event' => response_hash,
                                                  'agent_id' => event.agent_id, 'event_id' => event.id })
      end
    end
  end
end
