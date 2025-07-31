# clipimage

A simple CLI tool to save clipboard images to files.

## Installation

```bash
npm install -g clipimage
```

## Usage

```bash
# Save clipboard image with default name (clipboard-image.png)
clipimage

# Save with custom filename
clipimage -o myimage.png

# Save in different format
clipimage -o myimage -f jpg

# Show help
clipimage --help
```

## Options

- `-o, --output`: Output file path (default: clipboard-image.png)
- `-f, --format`: Output format - png, jpg, jpeg, bmp (default: png)
- `-h, --help`: Show help

## Supported Platforms

- Windows
- macOS
- Linux (requires xclip)

## Linux Requirements

On Linux, you need to have `xclip` installed:

```bash
sudo apt-get install xclip  # Ubuntu/Debian
sudo yum install xclip      # RHEL/CentOS
```

## License

MIT