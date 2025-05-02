#
# convert.py
#
# Simple example of converting a PNG to data suitable for (unoptimized)
# software blitting on the Cody Computer's hires mode. The code here is
# only for example purposes (among other things, image width is limited
# to 256 pixels rather than 320). Color data is ignored. 
#
# Also note that for entire screens (rather than graphics intended to be
# drawn at random locations) it would make more sense to store the data
# in the native format and load it. See the hires examples in the Cody
# Computer repo for more information.
#
# To use this with the provided assembly language example, run the
# program on your source file and then include the output into your 
# assembly program.
#
from PIL import Image

# Load the image and convert to a 1-bit (black and white) image
image = Image.open("happy.png")
image = image.convert("1")
image_width, image_height = image.size

# Print the image header
print("IMG_WIDTH  = {}".format(image_width))
print("IMG_HEIGHT = {}".format(image_height))
print("")

# Generate image bytes
print("IMG_DATA")

bits = []
    
# Loop over each row in the image
for y in range(0, image_height):

    # Loop over each column in the image
    for x in range (0, image_width):
        
        # Convert each pixel value into a 0 or 1
        pixel = image.getpixel((x, y))
        if pixel == 0:
            bits.append("0")
        else:
            bits.append("1")
        
        # Emit a new BYTE each 8 bits
        if len(bits) == 8:
            print("    .BYTE %{}".format("".join(bits)))
            bits = []

# If we had bits left over (not byte-aligned to 8 bits) then pad
if len(bits):
    while len(bits) < 8:
        bits.append("0")
    print("    .BYTE %{}".format("".join(bits)))
