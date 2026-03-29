# Changelog

All notable changes to this project will be documented in this file.


## [2.7.1] - 2026-03-29

### Added
- **Manual Release Trigger**: Added `workflow_dispatch` to GitHub Actions, allowing users to trigger a build and release with a custom version tag directly from the GitHub UI.
- **Auto-Update Checker**: The app now automatically checks for new versions on GitHub at startup and prompts the user to update.

### Fixed
- **CI/CD Optimization**: Fixed code formatting and linting issues (missing curly braces) that were blocking the automated test pipeline.
- **Workflow Reliability**: Improved GitHub Actions stability and added a "Run workflow" button for manual testing.

## [2.7.0] - 2026-03-27

### Added
- **Poster & Zoom Support**: Added rich visual playlists using `cached_network_image`. The app now renders movie posters injected from MyPlaylist's proxy server and leverages VLC's native `/art` API.
- **Interactive Zoom**: Users can now tap on posters to view a full-screen, high-resolution version with a smooth zoom animation.


## [2.5.0] - 2026-03-27

### Added
- **VLC HTTP API Support**: Completely rewrote the connection provider.

## [2.4.0] - 2026-03-26

### Added
- **Kill VLC**: Added functionality to force-stop all VLC instances (both local and remote via MyPlaylist).
- **New Button**: Inserted "Kill VLC" action in both the Info Dialog and the "Smart Actions" panel.
- **Maintenance**: Added support for critical system commands during control sessions.

## [2.3.0] - 2026-01-21

### Synchronization
- **MyPlaylist v3.4.0 Compatibility**: Fully synchronized protocol to support the latest playlist generation logic.
- **Improved Series Support**: Enhanced metadata handling for TV series and episodes, including better badge rendering in previews.

### Maintenance
- Updated internal protocol definitions for improved stability during remote control sessions.
- General performance improvements and documentation synchronization.


### MyPlaylist Synchronization (v3.0.0)
- **Exclusion Filters**: Added support for excluded genres and years in smart playlist generation.
- **Actor & Director Filters**: Added new input fields for including/excluding specific actors and directors.
- **Rich Metadata Preview**: Preview playlist now displays series indicators (TV icon and "SERIE" badge) to match MyPlaylist v3.0.0.
- **Protocol Extension**: Updated communication protocol to handle complex metadata and advanced filter arguments.

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
