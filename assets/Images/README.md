# App Icon Instructions

## How to Change the App Logo

### If you have an SVG file:

1. **Convert SVG to PNG:**
   - **Option A - Online (Easiest):**
     - Go to https://cloudconvert.com/svg-to-png or https://convertio.co/svg-png/
     - Upload your SVG file
     - Set output size to **1024x1024 pixels**
     - Download the PNG file
   
   - **Option B - Using Inkscape (Free):**
     ```bash
     inkscape --export-type=png --export-width=1024 --export-height=1024 your_logo.svg
     ```
   
   - **Option C - Using ImageMagick:**
     ```bash
     convert -background none -resize 1024x1024 your_logo.svg app_icon.png
     ```
   
   - **Option D - Using GIMP or Photoshop:**
     - Open SVG in GIMP/Photoshop
     - Export as PNG at 1024x1024 resolution

2. **Place the PNG file:**
   - Name it: `app_icon.png`
   - Place it in this directory: `assets/Images/app_icon.png`

### If you already have a PNG:

1. **Prepare your logo image:**
   - Recommended size: **1024x1024 pixels**
   - Format: **PNG** (with transparency if needed)
   - Name it: `app_icon.png`
   - Place it in this directory: `assets/Images/app_icon.png`

### Generate the icons:

```bash
flutter pub get
dart run flutter_launcher_icons
```

**Note:** If you get an error, make sure you've run `flutter pub get` first to install the package.

### Rebuild your app:

```bash
flutter clean
flutter run
```

## Icon Requirements

- **Android**: Will generate icons for all densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- **iOS**: Will generate all required sizes (20x20, 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 1024x1024)

## Tips

- **SVG Conversion:** When converting SVG to PNG, ensure the SVG is square (1:1 aspect ratio) before conversion
- Use a square image (1:1 aspect ratio)
- Keep important content in the center (Android adaptive icons may crop edges)
- Use a transparent background if you want the icon to blend with the device theme
- Test on both light and dark backgrounds if using adaptive icons
- **For SVG files:** Make sure to export at high resolution (1024x1024) to maintain quality

## Current Configuration

The app icon configuration is in `pubspec.yaml` under `flutter_launcher_icons`.
You can customize:
- Different icons for Android and iOS
- Adaptive icon background color
- Whether to remove alpha channel for iOS

