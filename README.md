> [!IMPORTANT]
> Please note that this module will automatically add all user certificate authorities of the main user (uid=0) as system CAs.
> 
> So do not add any untrusted CAs, which may cause your device to lose security.
# custom-certificate-authorities
Automatically add user-added certificates to the system store.
## Quick Start
Install the module and add CAs in Android settings then reboot, everything will be done automatically.
## Supported Versions
Android upto 14 (9-14 tested)
## Credits
- [Magisk](https://github.com/topjohnwu/Magisk/): Makes all these possible
- [Termux](https://grimler.se/termux-packages-24/pool/main/o/openssl/): Converts certificate format
