package SL::Dispatcher::AuthHandler::Admin;

use strict;

use parent qw(Rose::Object);

sub handle {
  %::myconfig = ();

  return if  $::form->{'{AUTH}admin_password'} && ($::auth->authenticate_root($::form->{'{AUTH}admin_password'})            == $::auth->OK());
  return if !$::form->{'{AUTH}admin_password'} && ($::auth->authenticate_root($::auth->get_session_value('admin_password')) == $::auth->OK());

  $::auth->delete_session_value('admin_password');
  SL::Dispatcher::show_error('login/password_error', 'password', is_admin => 1);
}

1;
