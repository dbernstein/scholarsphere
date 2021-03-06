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

require 'spec_helper'

describe 'host_to_vhost' do
  it "should return the proper vhost on ss1test" do
    Socket.stubs(:gethostname).returns('ss1test')
    Rails.application.get_vhost_by_host[0].should == 'scholarsphere-integration.dlt.psu.edu-8443'
    Rails.application.get_vhost_by_host[1].should == 'https://scholarsphere-integration.dlt.psu.edu:8443/'
  end
  it "should return the proper vhost on ss2test" do
    Socket.stubs(:gethostname).returns('ss2test')
    Rails.application.get_vhost_by_host[0].should == 'scholarsphere-test.dlt.psu.edu'
    Rails.application.get_vhost_by_host[1].should == 'https://scholarsphere-test.dlt.psu.edu/'
  end
  it "should return the proper vhost on ss3test" do
    Socket.stubs(:gethostname).returns('ss3test')
    Rails.application.get_vhost_by_host[0].should == 'scholarsphere-demo.dlt.psu.edu'
    Rails.application.get_vhost_by_host[1].should == 'https://scholarsphere-demo.dlt.psu.edu/'
  end
  it "should return the proper vhost on ss1qa" do
    Socket.stubs(:gethostname).returns('ss1qa')
    Rails.application.get_vhost_by_host[0].should == 'scholarsphere-qa.dlt.psu.edu'
    Rails.application.get_vhost_by_host[1].should == 'https://scholarsphere-qa.dlt.psu.edu/'
  end
  it "should return the proper vhost on ss1stage" do
    Socket.stubs(:gethostname).returns('ss1stage')
    Rails.application.get_vhost_by_host[0].should == 'scholarsphere-staging.dlt.psu.edu'
    Rails.application.get_vhost_by_host[1].should == 'https://scholarsphere-staging.dlt.psu.edu/'
  end
  it "should return the proper vhost on ss1prod" do
    Socket.stubs(:gethostname).returns('ss1prod')
    Rails.application.get_vhost_by_host[0].should == 'scholarsphere.psu.edu'
    Rails.application.get_vhost_by_host[1].should == 'https://scholarsphere.psu.edu/'
  end
  it "should return the proper vhost on dev" do
    Socket.stubs(:gethostname).returns('some1host')
    Rails.application.get_vhost_by_host[0].should == 'some1host'
    Rails.application.get_vhost_by_host[1].should == 'https://some1host/'
  end
end
