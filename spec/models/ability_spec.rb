require 'spec_helper'
require "cancan/matchers"

describe Ability do
  describe "a user" do
    let (:sender) { FactoryGirl.create(:test_user_1) }
    let (:user) { FactoryGirl.create(:user) }
    let (:file) do
      GenericFile.new.tap do|file|
        file.apply_depositor_metadata(sender.user_key)
        file.save!
      end
    end
    subject { Ability.new(user)}

    context "with a ProxyDepositRequest that they receive" do
      let (:request) { ProxyDepositRequest.create!(pid: file.pid, receiving_user: user, sending_user: sender) }
      it { should be_able_to(:accept, request) }
    end 

    context "with a ProxyDepositRequest they are not the receiver of" do
      let (:request) { ProxyDepositRequest.create!(pid: file.pid, receiving_user: sender, sending_user: user) }
      it { should_not be_able_to(:accept, request) }
    end
  end
end
