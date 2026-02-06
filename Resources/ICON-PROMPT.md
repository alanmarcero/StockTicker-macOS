# App Icon — AI Image Generator Prompts

Use these prompts to generate a polished raster app icon with AI image generators.

## Midjourney

```
macOS app icon for a stock ticker menu bar app, dark navy blue gradient background (#0A1628 to #1B2A4A), bright green (#34C759) upward-trending stock chart line with subtle glow effect, area fill fading to transparent below the line, 2-3 simplified candlestick bars as accent, minimal grid lines, rounded squircle shape, clean modern design, high contrast, recognizable at small sizes --ar 1:1 --s 250 --v 6.1
```

## DALL-E

```
A macOS application icon in the Apple squircle shape. Dark navy blue gradient background transitioning from very dark blue at the top to slightly lighter navy at the bottom. The main element is a bright green upward-trending line chart with 5-6 data points connected by a thick glowing line. Below the line there is a subtle green gradient area fill that fades to transparent. On the right side, 2-3 simplified stock candlestick bars in green and red. Very faint horizontal grid lines in the background. Clean, modern, minimal design. The icon should be clearly readable even at 16x16 pixels. No text, no borders, no 3D effects.
```

## Design Notes

- The SVG in `AppIcon.svg` provides a starting point for the color scheme and composition
- Key requirement: the upward-diagonal green line must remain recognizable at 16px (menu bar size)
- Green-on-navy provides excellent contrast in both light and dark macOS themes
- The squircle radius matches Apple's macOS icon shape (229px at 1024x1024)

## Converting to PNG

After generating or refining the icon, export to these sizes for `Assets.xcassets/AppIcon.appiconset`:

| Size | Scale | Filename |
|------|-------|----------|
| 16x16 | 1x | icon_16x16.png |
| 16x16 | 2x | icon_16x16@2x.png |
| 32x32 | 1x | icon_32x32.png |
| 32x32 | 2x | icon_32x32@2x.png |
| 128x128 | 1x | icon_128x128.png |
| 128x128 | 2x | icon_128x128@2x.png |
| 256x256 | 1x | icon_256x256.png |
| 256x256 | 2x | icon_256x256@2x.png |
| 512x512 | 1x | icon_512x512.png |
| 512x512 | 2x | icon_512x512@2x.png |

To convert the SVG using `librsvg` (install with `brew install librsvg`):

```bash
for size in 16 32 64 128 256 512 1024; do
  rsvg-convert -w $size -h $size Resources/AppIcon.svg -o "icon_${size}x${size}.png"
done
```

Then update `Assets.xcassets/AppIcon.appiconset/Contents.json` with the filenames.
