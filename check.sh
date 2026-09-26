#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc Schedule.swift Tests/LogicChecks.swift -o .build/logic-checks
.build/logic-checks
xcodebuild -project NextU.xcodeproj -scheme NextU -sdk iphonesimulator -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
