# Altra


## Configuration

### Motherboard

Manufacturer: ASRockRack
Product Name: ALTRAD8UD-1L2T

![Motherboard](motherboard.svg)

![Block Diagram](block-diagram.svg)

My particular unit definitely has the AST2500 connected to the X550 and I210
over NSCI (The BOM optional line).

I have it hooked only on the X550 port and both the main machine and the BMC
gets an IP address from my router.


* `M2_1` is hooked up to a `WD Black SN850X 2TB`
* `TPM` is hooked up to an [`ASROCK TPM-SPI`](https://asrock.com/mb/spec/product.asp?Model=TPM-SPI) which is a NPCT75x
`
* `USB3 Header` is connected to front panel


### CPU

Manufacturer: Ampere(R)
Version: Ampere(R) Altra(R) Max Processor
Part Number: M128-30

Sourced off US Ebay. Bought from somebody in SoCal.

It's an engineering sample. Not writing down the serial number here so
that the seller doesn't get into trouble. We deduced from
the fact that the chip pacakge is marked as "ES" and the boot logs.


![ROT](https://cf-assets.www.cloudflare.com/zkvhlag99gkb/1uctsORF4iINvxIpkpAMCM/34e931a29cc21a6b0e9d3549e81abcf8/image7-5.png)
More info about ARM Secure Boot can be found here: https://blog.cloudflare.com/armed-to-boot/


Boot log on port 2201. This seems to be
the logs of the SMPro co-processor.
Note the complaints about pub key hash mismatch.
And not being able to authenticate the BL1 image.

```
S0-cli>
S0-cli>
S0-cli> P029

SMpro Runtime Firmware v2.10.20230517
Failsafe: 0
P035

Pub key verify fail: 84:0xF1000009

Calculated pub key hash: 85: len: 32
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
CENSOREDTOPROTECTSOURCEXXXXXXXXX


Actual pub key hash: 86: len: 32
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
CENSOREDTOPROTECTSOURCEXXXXXXXXX


CommonCertVerify fail: 267:0xF1000006

CommonCertVerify fail: 345:0xF1000006
E559
Board: config 0
Available CPM: 0xFFFFFFFFFFFFFFFF
P036
P038
ERR: Auth BL1 image 0xFFFFF8EE
E571
Probe I2C10 DIMM0
Probe I2C10 DIMM1
Probe I2C10 DIMM2
Probe I2C10 DIMM3
Probe I2C10 DIMM4
Probe I2C10 DIMM5
Probe I2C10 DIMM6
Probe I2C10 DIMM7
Probe I2C2 DIMM0
Probe I2C2 DIMM1
Probe I2C2 DIMM2
Probe I2C2 DIMM3
Probe I2C2 DIMM4
Probe I2C2 DIMM5
Probe I2C2 DIMM6
Probe I2C2 DIMM7
DDR: Operational     DIMM: 0x00001515
DDR: Failure         DIMM: 0x00000000
DDR: Non-Operational DIMM: 0x00000000
P026
P033
P028
P054

PMpro output start
PMpro Runtime Firmware v2.10.20230517
I2C0: Clear bus
2P mode: 0x00000003
ICCMax Vrm OC limit 536
ICCMax max cur limit 414

PMpro output complete
P012
S0-cli> ZQCS period(msec): 200

S0-cli>
```

Port 2202. this seems to be the logs of the actual CPU loading the BL1
firmware.


Note the  "ROTPK is not deployed on platform. Skipping ROTPK verification."
https://github.com/ARM-software/arm-trusted-firmware/blob/f3bfd2fa6c65e92447231b5b5fee200bfe3a70f5/drivers/auth/auth_mod.c#L249


It seems that the `plat_get_rotpk_info` implementation on the Ampere is returning
`ROTPK_NOT_DEPLOYED` which seems to be congruent with the errors we see in the S0
boot logs as well.

https://trustedfirmware-a.readthedocs.io/en/v2.12/porting-guide.html

> ROTPK_NOT_DEPLOYED : This allows the platform to skip certificate ROTPK
  verification while the platform ROTPK is not deployed. When this flag is set,
  the function does not need to return a platform ROTPK, and the authentication
  framework uses the ROTPK in the certificate without verifying it against the
  platform value. This flag must not be used in a deployed production
  environment.


In conclusion. the eFUSE root of trust is failing here.



```
NOTICE:  System reboot request
NOTICE:  Booting Trusted Firmware
NOTICE:  BL1: v2.1(release):2.10 Build 20230517
NOTICE:  BL1: Built : 18:37:49, May 17 2023
ERROR:   Failed to populate ROTPK error -16512
ERROR:   Failed to populate rotpk key der
NOTICE:  ROTPK is not deployed on platform. Skipping ROTPK verification.
NOTICE:  BL1: Booting BL2
NOTICE:  BL2: v2.1(release):2.10 Build 20230517
NOTICE:  BL2: Built : 18:37:49, May 17 2023
ERROR:   Failed to populate ROTPK error -16512
ERROR:   Failed to populate rotpk key der
NOTICE:  ROTPK is not deployed on platform. Skipping ROTPK verification.
NOTICE:  BL1: Booting BL31
NOTICE:  BL31: v2.1(release):2.10 Build 20230517
NOTICE:  BL31: Built : 18:37:49, May 17 2023
NOTICE:  BL31: Image v2.10 - Build 20230517
NOTICE:  PCIE HP: Enable
NOTICE:  SP: Memory Region Resource list found
NOTICE:  Booting Ampere TPM
NOTICE:  Built : 18:37:51, May 17 2023
NOTICE:  v2.1(release):c4503ec
NOTICE:  Running at S-EL0
NOTICE:  Secure Partition memory layout:
NOTICE:    Image regions
NOTICE:      Text region            : 0x90000000 - 0x90034000
NOTICE:      Read-only data region  : 0x90034000 - 0x9003d000
NOTICE:      Data region            : 0x9003d000 - 0x9003e000
NOTICE:      BSS region             : 0x9003e000 - 0x90042000
NOTICE:      Total image memory     : 0x90000000 - 0x90400000
NOTICE:    SPM regions
NOTICE:      SPM <-> SP buffer      : 0x90400000 - 0x90410000
NOTICE:      NS <-> SP buffer       : 0x88500000 - 0x88600000
NOTICE:  Booting Ampere Hotplug SP
NOTICE:  Built : 18:37:56, May 17 2023
NOTICE:  v2.1(release):c4503ec
NOTICE:  Running at S-EL0
NOTICE:  Secure Partition memory layout:
NOTICE:    Image regions
NOTICE:      Text region            : 0x90000000 - 0x90008000
NOTICE:      Read-only data region  : 0x90008000 - 0x9000a000
NOTICE:      Data region            : 0x9000a000 - 0x9000b000
NOTICE:      BSS region             : 0x9000b000 - 0x9000e000
NOTICE:      Total image memory     : 0x90000000 - 0x90400000
NOTICE:    SPM regions
NOTICE:      SPM <-> SP buffer      : 0x90400000 - 0x90410000
NOTICE:      NS <-> SP buffer       : 0x88400000 - 0x88500000
NOTICE:  HP: Initialize PCIE port
NOTICE:  HP: Socket 1
NOTICE:  HP: Port info
NOTICE:  HP: SCP message S0 0x0 0x0
NOTICE:  HP: SCP PCIE PHY message S0 0x0 0x0
NOTICE:  HP: Ready
```


### Memory

We use the `M393A4K40EB3-CWE` DDR4 memory module from Samsung.
They've been sourced second hand from two eBay Sellers




| ID    | Location | Part Number      | Serial Number | Seller | Notes
|-------|----------|------------------|---------------|--------|-------
| DDR0  | DDR4_A1  | M393A4K40EB3-CWE | 4897E0A5      | 1      |
| DDR1  | DDR4_B1  | M393A4K40EB3-CWE | 51A207B1      | 1      |
| DDR2  | DDR4_C1  | M393A4K40EB3-CWE | 51A2129A      | 1      |
| DDR3  | DDR4_D1  | M393A4K40EB3-CWE | 42B3A461      | 2      | BMC reports it as "absent" for some reason
| DDR4  | DDR4_E1  | M393A4K40EB3-CWE | 4897DD10      | 1      |
| DDR5  | DDR4_F1  | M393A4K40EB3-CWE | 17EBF7AD      | 1      |
| DDR6  | DDR4_G1  | M393A4K40EB3-CWE | 51A207AA      | 1      |
| DDR7  | DDR4_H1  | M393A4K40EB3-CWE | 42A9A51B      | 2      | BMC reports it as "absent" for some reason

## Quirks

The Aptio firmware seems to be highly non-compliant with the UEFI spec for TPM measurements.
We are thinking of flashing EDK-II firmware to fix this.
