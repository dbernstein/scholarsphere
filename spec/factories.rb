# Copyright © 2012 The Pennsylvania State University
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FactoryGirl.define do
  factory :user, :class => User do |u|
    login 'jilluser'
    ldap_available true
  end

  factory :archivist, :class => User do |u|
    login 'archivist1'
    ldap_available true
  end

  factory :curator, :class => User do |u|
    login 'curator1'
    ldap_available true
  end

  factory :random_user, :class => User do |u|
    sequence(:login) {|n| "user#{n}" }
    ldap_available true
  end


  #these two users are ONLY for ensuring our staging test users don't show up in search results
  factory :test_user_1, :class => User do |u|
    login 'tstem31'
  end

  factory :test_user_2, :class => User do |u|
    login 'testapp'
  end

end

