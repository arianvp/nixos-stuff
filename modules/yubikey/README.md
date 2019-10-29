# Yubikey
This module contains all Yubikey-related configuration

## Setting up ssh key on yubikey

The guide for this can be found here: https://developers.yubico.com/PIV/Guides/  



## Setting up the key



```
# This first step means you need to trust yubikeys RNG. which you shouldn't
# Instead, generate the private key on your laptop and transfer it to yubikey. see above link
# I just did this because it's convenient and I should feel bad.
yubico-piv-tool -s 9a -a generate -o public.pem
yubico-piv-tool -a verify-pin -a selfsign-certificate -s 9a -S "/CN=SSH key/" -i public.pem -o cert.pem
yubico-piv-tool -a import-certificate -s 9a -i cert.pem
ssh-keygen -f public.pem -i mPKCS8 > id_rsa.pub
```
