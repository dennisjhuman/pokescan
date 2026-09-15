#!/bin/sh
# Run the app on the Flutter web dev server.
#
# Why this wrapper exists: when Xcode's licence has not been accepted, *every*
# flutter command exits 69 with "You have not agreed to the Xcode license
# agreements" — including `flutter build web`, which has nothing to do with
# Xcode. An Xcode update re-arms that check on its own, and the failure looks
# like a broken dev server rather than an Xcode problem.
#
# So: use Xcode normally when it works, and fall back to the Command Line
# Tools (own SDKs, no licence gate) when it does not, so the web loop keeps
# running while someone gets round to:
#
#     sudo xcodebuild -license
#
# Note the fallback does not rescue `flutter test`: package:objective_c, pulled
# in by ML Kit, shells out to a bare xcrun that ignores DEVELOPER_DIR.
set -e

cd "$(dirname "$0")/.."

case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:$PATH"; export PATH ;;
esac

if ! xcodebuild -version >/dev/null 2>&1 && [ -d /Library/Developer/CommandLineTools ]; then
  echo "dev_web: Xcode is unusable (licence not accepted?), falling back to Command Line Tools." >&2
  echo "dev_web: run 'sudo xcodebuild -license' to fix it properly; flutter test needs it." >&2
  DEVELOPER_DIR=/Library/Developer/CommandLineTools
  export DEVELOPER_DIR
fi

exec flutter run -d web-server --web-port=8787 --web-hostname=localhost "$@"
