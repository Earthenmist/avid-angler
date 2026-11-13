# Bundled launcher libraries

These third-party Lua files are included unchanged from the official
[LibDBIcon v12.0.3 package](https://www.wowace.com/projects/libdbicon-1-0/files/8448436).
They retain their upstream ownership and notices, independently of the addon.

- LibStub, minor 2: public domain; credits and declaration in the source.
- CallbackHandler-1.0, minor 8: [upstream BSD notice](https://www.wowace.com/project/15049/license), reproduced in LICENSE-CallbackHandler.txt (including upstream placeholders).
- LibDataBroker-1.1, minor 4: by Tekkub and contributors; [upstream repository](https://github.com/tekkub/libdatabroker-1-1). Distributed as the unmodified dependency supplied in the official LibDBIcon bundle; no relicensing is asserted. [Project notice](https://www.wowace.com/project/20113/license): All Rights Reserved unless otherwise explicitly stated.
- LibDBIcon-1.0, minor 56: [Ace3-style BSD notice](https://www.wowace.com/project/15552/license), reproduced in LICENSE-LibDBIcon.txt.

Load order: LibStub, CallbackHandler, LibDataBroker, LibDBIcon. No separate
library installation is required. LibStub shares compatible library versions
with other installed addons.
