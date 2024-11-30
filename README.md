# Video Insight

Video Insight is a macOS application that helps you analyze video content by extracting text using OCR (Optical Character Recognition) and generating summaries using Ollama AI. It's particularly useful for processing educational videos, presentations, or any content with text overlays.

## Features

- **Video Frame Analysis**: Automatically extracts frames from videos and performs OCR
- **Text Recognition**: Uses Vision framework to detect and extract text from video frames
- **AI-Powered Summaries**: Generates concise summaries of extracted text using Ollama
- **Interactive Timeline**: Visual timeline of video frames with extracted text
- **Video Playback**: Built-in video player with frame-specific navigation
- **Text Editing**: Edit and correct OCR results manually
- **Multiple Export Options**: Copy summaries in plain text or markdown format

## TBD

- [ ] Add voice-to-text recognition and integrate it in summary
- [ ] Store video anaysis history locally
- [ ] Chat to Ollama in summary panel
- [ ] Integrate video frames and summary into a document

## Requirements

- macOS
- [Ollama](https://ollama.com) installed locally (or accessible via network)
- Sufficient disk space for video processing

## Setup

1. Install Ollama on your machine
2. Pull models (llama3.2:3b is suggested). Paste the following command in the terminal:
   ```
   ollama pull llama3.2:3b
   ```
   
4. Launch Video Insight
5. Configure Ollama settings (⌘,):
   - Ollama URL (default: localhost:11434)
   - Model name (default: llama3.2:3b)
   - Summary copy format preference

## Usage

### Basic Operations

1. **Import Video**:
   - Drag and drop video files into the app
   - Use Open Video button (⌘O)

2. **Navigate Content**:
   - Use the timeline on the right to browse video frames
   - Click on frames to view extracted text
   - Use the video player controls for playback

3. **View and Edit Text**:
   - View OCR text below the video
   - Edit text using the Edit button (⌘E)
   - Reset edited text using Reset button (⌘⇧R)

4. **Generate Summaries**:
   - Click Summarize button (⌘⇧S) to generate AI summary
   - View summaries in markdown format
   - Copy summaries using the Copy button

### Keyboard Shortcuts

- `⌘O` - Open video
- `⌘,` - Open settings
- `⌘E` - Toggle text editing
- `⌘⇧R` - Reset text to OCR
- `⌘R` - Jump to current frame
- `⌘⇧S` - Generate/view frame summary
- `⌥⇧S` - Generate/view video summary
- `⌘⇧C` - Copy text
- `⌥⇧C` - Copy frame image
- `⌘⇧L` - Toggle sidebar
- `⌘1-9` - Quick switch between videos

## How It Works

1. The app processes videos by extracting frames at regular intervals
2. Each frame is analyzed using Vision framework for text extraction
3. Extracted text is filtered to remove duplicates and irrelevant content
4. Ollama AI generates concise summaries of the extracted text
5. Results are presented in an interactive interface for easy navigation

## Tips

- For best results, use videos with clear, readable text
- Adjust playback to verify text extraction accuracy
- Edit OCR results manually if needed for better summaries
- Use keyboard shortcuts for faster navigation
- Configure Ollama model based on your needs (different models may provide different summary styles)

## Privacy & Security

- All processing is done locally on your machine
- No data is sent to external servers (except to your configured Ollama instance)
- Video files are accessed with read-only permissions
