#!/bin/sh
# Run the app on the Flutter web dev server.
#
# Why this wrapper exists: when Xcode's licence has not been accepted, *every*
# flutter command exits 69 with "You have not agreed to the Xcode license
# agreements" — including `flutter build web`, which has nothing to do with
# Xcode. An Xcode update re-arms that check, so it comes back on its own.
#
# Pointing DEVELOPER_DIR at the Command Line Tools sidesteps the licence check
# without needing a password. It costs nothing on web and is ignored once the
# licence is accepted with:
#
#     sudo xcodebuild -license
#
# Delete this file and go back to calling flutter directly when iOS builds
# start mattering.
set -e

cd "$(dirname "$0")/.."

case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:$PATH"; export PATH ;;
esac

if [ -d /Library/Developer/CommandLineTools ]; then
  DEVELOPER_DIR=/Library/Developer/CommandLineTools
  export DEVELOPER_DIR
fi

exec flutter run -d web-server --web-port=8787 --web-hostname=localhost "$@"
