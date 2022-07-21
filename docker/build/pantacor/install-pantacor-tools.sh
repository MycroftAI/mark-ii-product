#!/usr/bin/env bash
set -euo pipefail

chmod +x /usr/local/bin/pvsocket
chmod +x /usr/local/bin/pvlog
chmod +x /usr/local/bin/pvmeta
chmod +x /usr/local/bin/pvreboot
chmod +x /usr/local/bin/pvpoweroff

# systemctl enable pvpoweroff
# systemctl enable pvreboot
