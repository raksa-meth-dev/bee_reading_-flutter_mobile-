# 🐝 Bee Reading

**Bee Reading** is a clean, modern eBook and Audiobook reader app built with Flutter. It lets you import, read, and listen to your favorite books (EPUB & PDF) all in one place with a smooth, customizable reading experience.

---

## ✨ Features

### 📖 eBook Reader
- **Supports EPUB & PDF** formats.
- **Customizable reader**: adjust font size, themes, and reading layout.
- **Bookmarks & Notes**: save your favorite parts and jump back anytime.
- **Progress Tracking**: automatically saves your reading position.

### 🎧 Audiobook & Text-to-Speech (TTS)
- **Built-in TTS Player**: converts your eBooks into audiobooks instantly.
- **Audiobook Hub & Dedicated Player**: full playback controls (play, pause, skip, seek).
- **Chapter Navigation**: easily switch between chapters.
- **Sleep Timer**: set a timer to automatically stop playback before you sleep.
- **Speed Control**: choose playback speed from 0.5x up to 3.0x.
- **Car Mode**: a distraction-free, large-button interface designed for safe listening while commuting.

### 📚 Personal Library
- **Import Local Files**: pick books directly from your device storage.
- **Local Database (Drift / SQLite)**: your books, reading progress, and preferences stay on your device and work completely offline.
- **Organized Shelves**: keep track of what you are currently reading, want to read, or have completed.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`)
- **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod`)
- **Local Database**: [Drift](https://drift.simonbinder.eu) (SQLite)
- **Book Parsing & Rendering**:
  - `epub_pro` & `flutter_widget_from_html_core` (EPUB)
  - `pdfrx` (PDF)
- **Text-to-Speech**: `flutter_tts`

---

## 🚀 Getting Started

### Prerequisites

Make sure you have installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or later)
- An emulator or connected physical device (Android / iOS)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/bee_reading.git
   cd bee_reading
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code generation (for Drift database):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 📁 Project Structure

```text
lib/
├── config/       # App constants and configuration
├── database/     # Drift database schemas and DAOs
├── models/       # Data models
├── providers/    # Riverpod state providers
├── screens/      # App views (Home, Library, Reader, Audiobook)
│   ├── audiobook/# Audiobook player screens and sheets
│   └── reader/   # EPUB and PDF reading views
├── services/     # TTS, file import, and book content services
├── theme/        # App styling and color schemes
└── widgets/      # Reusable UI components
```

---

## 📄 License

This project is licensed for personal and educational use. Feel free to customize it to your needs!
