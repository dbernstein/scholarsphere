class SessionsController < ApplicationController
  def destroy
    cookies.delete(request.env['COSIGN_SERVICE']) if request.env['COSIGN_SERVICE']
    
    # make any local additions here (e.g. expiring local sessions, etc.)
    # adapted from here: http://cosign.git.sourceforge.net/git/gitweb.cgi?p=cosign/cosign;a=blob;f=scripts/logout/logout.php;h=3779248c754001bfa4ea8e1224028be2b978f3ec;hb=HEAD
    
    redirect_to ScholarSphere::Application.config.logout_url
  end
end