#!/bin/bash

echo "⚙️ Applying Aerospace-optimized system settings..."

# Dock & Mission Control optimizations
defaults write com.apple.spaces spans-displays -bool true
defaults write com.apple.dock expose-group-apps -bool false
defaults write com.apple.dock workspaces-auto-swoosh -bool false
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dashboard enabled-state -int 1
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Disable Space-switching hotkeys
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 79 "{enabled = 0;}"  # Ctrl+←
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 81 "{enabled = 0;}"  # Ctrl+→
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 32 "{enabled = 0;}"  # Mission Control
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 34 "{enabled = 0;}"  # App Exposé

# Disable trackpad gestures related to Spaces & Mission Control
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerVertSwipeGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadFiveFingerPinchGesture -int 0
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerVertSwipeGesture -int 0

killall Dock

echo "✅ Aerospace system tuning complete."
echo "⚠️ Log out and back in to fully apply display Space changes."
