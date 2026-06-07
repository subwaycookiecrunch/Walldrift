from PIL import Image
import os

img = Image.open("./WallDrift/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")
img = img.convert("RGBA")

# We want to crop to the main bounding box of the logo.
# Let's see if the background is solid (e.g., white or black or transparent)
# First let's print the colors of the corners.
width, height = img.size
print(f"Size: {width}x{height}")
print(f"Top-Left: {img.getpixel((0, 0))}")
print(f"Center: {img.getpixel((width//2, height//2))}")

