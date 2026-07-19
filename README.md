# file_jarvis

A privacy-scoped personal file assistant that helps you find, organize, and understand files in user-approved folders while remembering work style and project context.

## Native MVP

This repo now includes a realistic native macOS MVP built with SwiftUI and the OpenAI API.

The native MVP is intentionally narrow:

- Menu bar utility UX
- One approved local folder at a time
- Local file listing inside that approved folder
- One `Ask Jarvis` prompt that sends only approved folder context to OpenAI
- Calm, Apple-leaning single-surface popover

## Product positioning

- Privacy-scoped file assistant
- Only sees user-approved folders and files
- Helps find, organize, and understand files
- Remembers enough context to help without becoming invasive

## Run the native MVP

1. Set your API key:

```bash
export OPENAI_API_KEY="your_api_key_here"
```

2. Launch the native app:

```bash
swift run file_jarvis_native
```

The app runs as a menu bar utility. Open it from the macOS menu bar.

## Project Structure

- `Package.swift`
- `Sources/FileJarvisNative/FileJarvisApp.swift`
- `Sources/FileJarvisNative/JarvisViewModel.swift`
- `Sources/FileJarvisNative/LocalFileAccess.swift`
- `Sources/FileJarvisNative/OpenAIClient.swift`
- `Assets/jarvis_launcher.png`

## Current limitations

- One approved folder at a time
- No file move/rename actions yet
- No deep indexing or project memory yet
- The older Electron/web prototype files are still present in the repo, but the native SwiftUI app is now the main MVP direction

## License

MIT
