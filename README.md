# ImageMerge
A simple tool to merge single layers to one image. Including preview window, layer reordering and visibility toggling functionality. Excluding any third-party dependencies.

I created this tool because I needed to combine multiple layers to single images. As I needed to decide which layers to combine, I could not use any batch mode and starting up The GIMP every time took way to long. This is the result of a few days of trying to understand GDI+.

## Usage
![Main GUI](https://raw.githubusercontent.com/Bioruebe/ImageMerge/master/documentation/01 MainGUI.png)

This is the main GUI. Simply follow the only instruction you see and drop one or more layers into the window.
Alternatively, you may want to change the settings using the icon on the bottom right of the window or view the about screen.

![Layers](https://raw.githubusercontent.com/Bioruebe/ImageMerge/master/documentation/02 Layer.png)

The file name input field is automatically filled with the first layer's name combined with ´_merged´.
You can now use the controls at the bottom to enable/disable layers or rearrange them.

![Layers, rearranged](https://raw.githubusercontent.com/Bioruebe/ImageMerge/master/documentation/03 Modification.png)

After you have finished set the file name to your likings and click the ´Save´ button. A new window will pop up for a short time, wait until it closes. Enjoy your merged image :)

## Limitations
- Layers must have the same size, otherwise the preview will not work correctly
- The program might crash after using the ´Clear´ button too much
- No auto-updater (only notification), no settings GUI
