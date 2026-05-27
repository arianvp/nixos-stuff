{ ... }:
{
  environment.variables = {
    SSH_SK_PROVIDER = "/usr/lib/ssh-keychain.dylib";
    SSH_ASKPASS = "true";
    SSH_ASKPASS_REQUIRE = "force";
  };
}
