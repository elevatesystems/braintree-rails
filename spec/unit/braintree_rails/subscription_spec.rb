require File.expand_path(File.join(File.dirname(__FILE__), '../unit_spec_helper'))

describe BraintreeRails::Subscription do
  before do
    stub_braintree_request(:get, '/subscriptions/subscription_id', :body => fixture('subscription.xml'))
  end

  describe '#initialize' do
    it 'should find subscription from braintree when given a subscription id' do
      subscription = BraintreeRails::Subscription.new('subscription_id')
      braintree_subscription = Braintree::Subscription.find('subscription_id')

      expect(subscription).to be_persisted
      expect(subscription.never_expires?).to eq(braintree_subscription.never_expires?)
      BraintreeRails::Subscription.attributes.each do |attribute|
        expect(subscription.send(attribute)).to eq(braintree_subscription.send(attribute)) if braintree_subscription.respond_to?(attribute)
      end
    end

    it 'should wrap a Braintree::Subscription' do
      braintree_subscription = Braintree::Subscription.find('subscription_id')
      subscription = BraintreeRails::Subscription.new(braintree_subscription)

      expect(subscription).to be_persisted
      BraintreeRails::Subscription.attributes.each do |attribute|
        expect(subscription.send(attribute)).to eq(braintree_subscription.send(attribute)) if braintree_subscription.respond_to?(attribute)
      end
    end

    it 'should extract values from hash' do
      subscription = BraintreeRails::Subscription.new(:id => 'new_id')

      expect(subscription).to_not be_persisted
      expect(subscription.id).to eq('new_id')
    end

    it 'should try to extract value from other types' do
      subscription = BraintreeRails::Subscription.new(OpenStruct.new(:id => 'foobar', :persisted? => true))

      expect(subscription).to be_persisted
      expect(subscription.id).to eq('foobar')

      subscription = BraintreeRails::Subscription.new(OpenStruct.new)
      expect(subscription).to_not be_persisted
    end
  end

  describe 'validations' do
    it 'should validate id' do
      subscription = BraintreeRails::Subscription.new
      subscription.valid?
      expect(subscription.errors[:id]).to be_blank

      subscription = BraintreeRails::Subscription.new(:id => '@#$%')
      subscription.valid?
      expect(subscription.errors[:id]).to_not be_blank
    end

    it 'should billing_day_of_month' do
      subscription = BraintreeRails::Subscription.new
      subscription.valid?
      expect(subscription.errors[:billing_day_of_month]).to be_blank

      [*(1..28), 31].each do |valid_day|
        subscription = BraintreeRails::Subscription.new(:billing_day_of_month => valid_day)
        subscription.valid?
        expect(subscription.errors[:billing_day_of_month]).to be_blank
      end

      [29, 30, 'foo'].each do |invalid_day|
        subscription = BraintreeRails::Subscription.new(:billing_day_of_month => invalid_day)
        subscription.valid?
        expect(subscription.errors[:billing_day_of_month]).to_not be_blank
      end
    end

    it 'should validate numericality of number_of_billing_cycles' do
      subscription = BraintreeRails::Subscription.new(:number_of_billing_cycles => 'foobar')
      subscription.valid?
      expect(subscription.errors[:number_of_billing_cycles]).to_not be_blank

      [123, '123', nil].each do |valid_number|
        subscription = BraintreeRails::Subscription.new(:number_of_billing_cycles => valid_number)
        subscription.valid?
        expect(subscription.errors[:number_of_billing_cycles]).to be_blank
      end

      [123.45, '123.45', 'foo'].each do |invalid_number|
        subscription = BraintreeRails::Subscription.new(:number_of_billing_cycles => 'foo')
        subscription.valid?
        expect(subscription.errors[:number_of_billing_cycles]).to_not be_blank
      end
    end

    it 'should validate number_of_billing_cycles is greater than current_billing_cycle' do
      subscription = BraintreeRails::Subscription.new(:number_of_billing_cycles => '2', :current_billing_cycle => '1')
      subscription.valid?
      expect(subscription.errors[:number_of_billing_cycles]).to be_blank

      subscription = BraintreeRails::Subscription.new(:number_of_billing_cycles => '2', :current_billing_cycle => '3')
      subscription.valid?
      expect(subscription.errors[:number_of_billing_cycles]).to_not be_blank
    end

    it 'should validate precence of payment_method_token if new_record?' do
      subscription = BraintreeRails::Subscription.new
      subscription.valid?
      expect(subscription.errors[:payment_method_token]).to_not be_blank

      subscription = BraintreeRails::Subscription.new(:payment_method_token => 'token')
      subscription.valid?
      expect(subscription.errors[:payment_method_token]).to be_blank
    end

    it 'should validate precence of plan_id if new_record?' do
      subscription = BraintreeRails::Subscription.new
      subscription.valid?
      expect(subscription.errors[:plan_id]).to_not be_blank

      subscription = BraintreeRails::Subscription.new(:plan_id => 'plan_id')
      subscription.valid?
      expect(subscription.errors[:plan_id]).to be_blank
    end

    it 'should validate numericality of price' do
      subscription = BraintreeRails::Subscription.new(:price => 'foobar')
      subscription.valid?
      expect(subscription.errors[:price]).to_not be_blank

      [123, 123.45, '123', '123.45', nil].each do |valid_price|
        subscription = BraintreeRails::Subscription.new(:price => valid_price)
        subscription.valid?
        expect(subscription.errors[:price]).to be_blank
      end

      subscription = BraintreeRails::Subscription.new(:price => 'foo')
      subscription.valid?
      expect(subscription.errors[:price]).to_not be_blank
    end

    it 'should validate numericality of trial_duration if trial_period' do
      subscription = BraintreeRails::Subscription.new(:trial_duration => 'foobar')
      subscription.valid?
      expect(subscription.errors[:trial_duration]).to be_blank

      subscription = BraintreeRails::Subscription.new(:trial_duration => 'foobar', :trial_period => true)
      subscription.valid?
      expect(subscription.errors[:trial_duration]).to_not be_blank

      [1, 9999, '123'].each do |valid_duration|
        subscription = BraintreeRails::Subscription.new(:trial_duration => valid_duration, :trial_period => true)
        subscription.valid?
        expect(subscription.errors[:trial_duration]).to be_blank
      end

      [0, 10000, 1.23, nil].each do |invalid_duration|
        subscription = BraintreeRails::Subscription.new(:trial_duration => invalid_duration, :trial_period => true)
        subscription.valid?
        expect(subscription.errors[:trial_duration]).to_not be_blank
      end
    end

    it 'should validate trial_duration_unit if trial_period' do
      subscription = BraintreeRails::Subscription.new(:trial_duration_unit => 'foobar')
      subscription.valid?
      expect(subscription.errors[:trial_duration_unit]).to be_blank

      subscription = BraintreeRails::Subscription.new(:trial_duration_unit => 'foobar', :trial_period => true)
      subscription.valid?
      expect(subscription.errors[:trial_duration_unit]).to_not be_blank

      ['day', 'month'].each do |valid_unit|
        subscription = BraintreeRails::Subscription.new(:trial_duration_unit => valid_unit, :trial_period => true)
        subscription.valid?
        expect(subscription.errors[:trial_duration_unit]).to be_blank
      end

      ["", "foo", nil].each do |invalid_duration|
        subscription = BraintreeRails::Subscription.new(:trial_duration_unit => invalid_duration, :trial_period => true)
        subscription.valid?
        expect(subscription.errors[:trial_duration_unit]).to_not be_blank
      end
    end

    it 'should validate first_billing_date to be valid future date' do
      [Date.today, Date.tomorrow, Date.tomorrow.to_s, nil].each do |valid_date|
        subscription = BraintreeRails::Subscription.new(:first_billing_date => valid_date)
        subscription.valid?
        expect(subscription.errors[:first_billing_date]).to be_blank
      end

      [Date.yesterday, "invalid date"].each do |invalid_date|
        subscription = BraintreeRails::Subscription.new(:first_billing_date => invalid_date)
        subscription.valid?
        expect(subscription.errors[:first_billing_date]).to_not be_blank
      end
    end
  end

  describe '#plan' do
    it 'should load plan from plan_id' do
      subscription = BraintreeRails::Subscription.new('subscription_id')
      braintree_subscription = Braintree::Subscription.find('subscription_id')
      stub_braintree_request(:get, '/plans', :body => fixture('plans.xml'))
      expect(subscription.plan.id).to eq(braintree_subscription.plan_id)
    end
  end

  describe '#credit_card' do
    it 'should load credit_card from payment_method_token' do
      subscription = BraintreeRails::Subscription.new('subscription_id')
      braintree_subscription = Braintree::Subscription.find('subscription_id')
      stub_braintree_request(:get, '/payment_methods/credit_card/credit_card_id', :body => fixture('credit_card.xml'))
      expect(subscription.credit_card.token).to eq(braintree_subscription.payment_method_token)
    end
  end

  [:add_ons, :discounts, :transactions].each do |association|
    describe "##{association}" do
      it 'behaves like enumerable' do
        braintree_subscription = Braintree::Subscription.find('subscription_id')
        subscription = BraintreeRails::Subscription.new(braintree_subscription)

        expect(subscription.send(association)).to respond_to(:each)
        expect(subscription.send(association).size).to eq(braintree_subscription.send(association).size)
      end

      it 'does not support create' do
        subscription = BraintreeRails::Subscription.new('subscription_id')
        expect {subscription.send(association).create}.to raise_error(BraintreeRails::NotSupportedApiException)
      end
    end
  end

  describe 'persistence' do
    before do
      stub_braintree_request(:post, '/subscriptions', :body => fixture('subscription.xml'))
      stub_braintree_request(:put, '/subscriptions/subscription_id', :body => fixture('subscription.xml'))
    end

    describe 'save, save!' do
      it 'should return true when saved' do
        subscription = BraintreeRails::Subscription.new(subscription_hash)
        expect(subscription.save).to eq(true)
        expect(subscription).to be_persisted
      end

      it 'should not throw error when not valid' do
        subscription = BraintreeRails::Subscription.new
        expect(subscription.save).to eq(false)
        expect(subscription).to_not be_persisted
      end

      it 'should return true when saved with bang' do
        subscription = BraintreeRails::Subscription.new(subscription_hash)
        expect(subscription.save!).to eq(true)
        expect(subscription).to be_persisted
      end

      it 'should throw error when save invalid record with bang' do
        subscription = BraintreeRails::Subscription.new(:first_name => 'f' * 256)
        expect { subscription.save! }.to raise_error(BraintreeRails::RecordInvalid)
        expect(subscription).to_not be_persisted
      end
    end

    describe 'update_attributes, update_attributes!' do
      it 'should return true when update_attributes' do
        subscription = BraintreeRails::Subscription.new(Braintree::Subscription.find('subscription_id'))
        expect(subscription.update_attributes(:price => '10')).to eq(true)
      end

      it 'should not throw error when not valid' do
        subscription = BraintreeRails::Subscription.new(Braintree::Subscription.find('subscription_id'))
        expect(subscription.update_attributes(:price => 'f' * 256)).to eq(false)
      end

      it 'should return true when update_attributesd with bang' do
        subscription = BraintreeRails::Subscription.new(Braintree::Subscription.find('subscription_id'))
        expect(subscription.update_attributes!(:price => '10')).to eq(true)
      end

      it 'should throw error when update_attributes invalid record with bang' do
        subscription = BraintreeRails::Subscription.new(Braintree::Subscription.find('subscription_id'))
        expect { subscription.update_attributes!(:price => 'f' * 256) }.to raise_error(BraintreeRails::RecordInvalid)
      end
    end

    describe 'cancel' do
      before do
        stub_braintree_request(:put, '/subscriptions/subscription_id/cancel', :body => fixture('subscription.xml'))
      end

      it 'should cancel subscription when Subscription.cancel' do
        BraintreeRails::Subscription.cancel('subscription_id')
      end
      it 'should cancel subscription when delete' do
        BraintreeRails::Subscription.delete('subscription_id')
      end

      it 'should cancel subscription when Subscription#cancel' do
        BraintreeRails::Subscription.new('subscription_id').cancel
      end

      it 'should cancel subscription when destroy' do
        BraintreeRails::Subscription.new('subscription_id').destroy
      end
    end
  end
end