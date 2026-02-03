# Best Markdown Readers for macOS

## Recommended Apps for Reading Markdown Files

### 1. **MacDown** ⭐ (FREE - Best for Developers)
- **Download**: https://macdown.uranusjr.com/
- **Why it's great**:
  - Free and open source
  - Live preview (edit + preview side-by-side)
  - GitHub Flavored Markdown support
  - Syntax highlighting for code blocks
  - Export to HTML/PDF
- **Best for**: Developers who want to read AND edit
- **Install via Homebrew**: `brew install --cask macdown`

### 2. **Marked 2** 💎 (PAID - $15.99 - Best for Reading)
- **Download**: https://marked2app.com/
- **Why it's great**:
  - Beautiful rendering
  - Multiple themes
  - Table of contents
  - Word count and reading time
  - Export to many formats
  - Watch files for changes
- **Best for**: Professional documentation reading
- **Price**: $15.99 (one-time purchase)

### 3. **Typora** 📝 (PAID - $14.99 - Best WYSIWYG)
- **Download**: https://typora.io/
- **Why it's great**:
  - WYSIWYG editing (what you see is what you get)
  - Clean, distraction-free interface
  - Excellent for writing and reading
  - Themes support
  - Export to PDF, HTML, Word
- **Best for**: Writing and reading in one seamless experience
- **Price**: $14.99 (one-time purchase)

### 4. **Visual Studio Code** 🆓 (FREE - Best All-in-One)
- **Download**: https://code.visualstudio.com/
- **Why it's great**:
  - Free and powerful
  - Built-in markdown preview (⌘K V)
  - Extensions for enhanced markdown
  - Already have it if you're a developer
  - Great for coding + documentation
- **Best for**: Developers who already use VS Code
- **Install via Homebrew**: `brew install --cask visual-studio-code`

### 5. **iA Writer** ✍️ (PAID - $49.99 - Best for Writing)
- **Download**: https://ia.net/writer
- **Why it's great**:
  - Minimal, focused interface
  - Beautiful typography
  - Focus mode
  - iCloud sync
  - Export options
- **Best for**: Professional writers
- **Price**: $49.99

### 6. **Obsidian** 🔗 (FREE - Best for Knowledge Base)
- **Download**: https://obsidian.md/
- **Why it's great**:
  - Free for personal use
  - Graph view for linked notes
  - Powerful plugin system
  - Local-first (your files stay on your Mac)
  - Great for organizing documentation
- **Best for**: Building a knowledge base of documentation
- **Install via Homebrew**: `brew install --cask obsidian`

---

## Quick Comparison

| App | Price | Best For | Ease of Use | Features |
|-----|-------|----------|-------------|----------|
| **MacDown** | FREE | Developers | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Marked 2** | $15.99 | Reading | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Typora** | $14.99 | Writing | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **VS Code** | FREE | Coding + Docs | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **iA Writer** | $49.99 | Professional Writing | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Obsidian** | FREE | Knowledge Base | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## My Top Recommendations for Your Use Case

### For Reading Project Documentation (ROADMAP.md, README.md, etc.)

**Option 1: MacDown** (FREE) ⭐
```bash
brew install --cask macdown
```
Then: Right-click any .md file → Open With → MacDown

**Option 2: VS Code** (FREE) - If you already have it
- Open VS Code
- Open the .md file
- Press `⌘K` then `V` to open preview
- Or click the preview icon in the top right

**Option 3: Marked 2** ($15.99) - If you want the best experience
- Beautiful rendering
- Great for long documents like your ROADMAP.md
- Worth the price if you read a lot of markdown

### For Quick Viewing in Finder

**QLMarkdown** (FREE) - QuickLook plugin for Markdown
```bash
brew install --cask qlmarkdown
```
After installing, you can press **Space** on any .md file in Finder to preview it!

---

## Installation Commands

### Install MacDown (Recommended)
```bash
brew install --cask macdown
```

### Install VS Code (If you don't have it)
```bash
brew install --cask visual-studio-code
```

### Install QLMarkdown (QuickLook Preview)
```bash
brew install --cask qlmarkdown
# Restart QuickLook
qlmanage -r
```

### Install Obsidian (For Knowledge Base)
```bash
brew install --cask obsidian
```

---

## How to Open Your Markdown Files

### Using MacDown (After Installation)
```bash
# Open specific file
open -a MacDown /Users/balaji/Projects/AndroidSwift/AndroidDeviceInfo/ROADMAP.md

# Or set as default app for .md files
# Right-click any .md file → Get Info → Open with: MacDown → Change All
```

### Using VS Code
```bash
# Open in VS Code
code /Users/balaji/Projects/AndroidSwift/AndroidDeviceInfo/ROADMAP.md

# Or open entire project
code /Users/balaji/Projects/AndroidSwift/AndroidDeviceInfo
```

### Using QuickLook (After installing QLMarkdown)
```bash
# In Finder, navigate to the file and press Space
# Or from terminal:
qlmanage -p /Users/balaji/Projects/AndroidSwift/AndroidDeviceInfo/ROADMAP.md
```

---

## My Personal Recommendation 🎯

**Install MacDown** - It's free, works great, and is perfect for developer documentation.

```bash
brew install --cask macdown
open -a MacDown /Users/balaji/Projects/AndroidSwift/AndroidDeviceInfo/ROADMAP.md
```

You'll get a beautiful side-by-side view with the markdown source on the left and rendered preview on the right. Perfect for reading your ROADMAP, README, and TESTING files!

**Bonus**: Also install QLMarkdown for quick previews in Finder with the Space bar.
