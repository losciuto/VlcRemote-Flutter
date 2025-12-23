# Changelog

All notable changes to this project will be documented in this file.


## [1.3.0] - 2025-12-23

### Performance & Efficiency
- **Optimized Polling**: Reduced status update interval from 500ms to 1000ms (-50% network traffic)
- **Command Delays**: Replaced hardcoded delays with named constants (100ms/300ms)
- **Volume Debouncing**: Added 300ms debounce to prevent command flooding during slider interaction
- **Seek Debouncing**: Implemented debounce mechanism for seek operations

### Error Handling & Resilience
- **Auto-Reconnect**: Exponential backoff strategy (1s → 2s → 4s → 8s → 16s, max 5 attempts)
- **Retry Logic**: 3 retry attempts for status updates before triggering reconnect
- **Improved Stability**: Status timer continues running during temporary failures

### Code Quality
- **Centralized Constants**: All magic numbers replaced with named constants in `AppConstants`
- **Resource Cleanup**: Proper disposal of debounce timers
- **Maintainability**: Single source of truth for all timing configurations

### UX Enhancements
- **Progress Feedback**: 10-step progress updates during MyPlaylist reconnection
- **Better Messages**: Enhanced status messages for user awareness

## [1.2.1] - 2025-12-21


- Documentation update and version synchronization.
- Expanded English README with full features and configuration guide.

## [1.2.0] - 2025-12-14

### Added
- **Interactive UI Controls**: Replaced static volume and playback progress displays with interactive sliders in the `ControlPanel`.
- **Redesigned Playlist Access**: Moved the playlist from a permanently visible panel to a separate, button-triggered modal view (bottom sheet).
- **New Branding**: Modern application icon applied across all platforms.
- **Improved Now Playing**: Removed redundant bars and improved visual clarity.
- **Optimization**: Better responsiveness for UI updates and seeking.

## [1.1.0] - 2025-12-11
- Initial release with basic VLC control functionality.
