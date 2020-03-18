# Default Weather FX implementation

This is a default Weather FX script. Everything is very simple, made to work fast.

<img src="https://i.imgur.com/zLdkWjp.jpg" />

## About forking:

If you want to, please feel free to use it as a base. That script is in public domain, meaning you can do whatever you want with it without giving any credit or anything like that (by the way, don’t forget to remove that LICENSE file unless you want your script to also be in public domain). I added a lot of comments to explain what it does as well. Hopefully, it would be helpful.

## Files in this repo:

- Regular git files, remove if not needed:
  - `LICENSE`: file declaring it as a work in public domain.
  - `README.md`: this read me file.
  - `.gitattributes`, `.gitignore`: two more files to make working with git easier.
- Actual weather implementation:
  - `manifest.ini`: contains extra information for that dropdown list in Content Manager.
  - `weather.lua`: main Weather FX script, could call it entry point. Loads files with actual code, triggers updates in them (skipping two frames and updating on third unless camera or lighting moved too much).
  - `clouds/atlas.dds`: atlas texture with cloud masks. More about them later.
  - `src/conditions_converter.lua`: reads correct conditions and turns them into a bunch of easy-to-handle values, like foggyness or cloudness. If you want to tweak different types of weathers, head here.
  - `src/consts.lua`: general consts like sun intensity, moon color or overall brightness;
  - `src/light_pollution.lua`: loads light pollution and prepares it to be applied to the sky and to separate clouds, trying to estimate not only its amount and relative in general, but its position relative to camera as well (only noticeable for very localized pollutions, set for smaller towns, like on Highlands track).
  - `src/utils.lua`: some general helping code for the whole thing to work, nothing interesting here.
  - `src/weather_application.lua`: does most of the actual weather work, setting light color and direction, ambient color, fog, adjusting overall brightness, setting parameters for a few cloud materials.
  - `src/weather_clouds.lua`: creates, moves and updates actual clouds, using materials from `src/weather_application.lua`. Clouds spawn in chunks around camera, and since Custom Shaders Patch expects cloud positions to be relative to camera, chunks are moved with camera, but in opposite direction, to create that movement.

## Cloud masks:

This script uses v2 of clouds shader, which uses volumetric noise for cloud details, and cloud mask for actual cloud shape. Cloud masks are stored in single atlas texture. At the start of `src/weather_clouds.lua`, you can see it referencing different types of clouds in that atlas texture, with starting point, size of each piece and total number.

Cloud mask uses four channels: first two for normal (red is as if cloud is lit from the left, green is as if cloud is lit from the top), blue channel is for extra sharpness map and alpha channel, well, alpha. There are a couple of PSD templates I prepared for drawing those, one for 1:1 square and another for 2:1 rectangle (other than aspect ratio, they’re the same). Inside, there is a smart object, inside of which there is another smart object (well, in fact there are two, but they’re linked). Double click [here](https://i.imgur.com/zTybbui.png) to open second smart object. Inside you will find some solid color layers with masks. Mask for layer group “Shape” is what defines the shape, activate it with Alt+Click [here](https://i.imgur.com/oTYh0JX.png) and start drawing with white and black brushes (use X button to quickly switch between the two). Same goes for second mask, it allows, optionally, to set edge areas with extra sharpness. Then, save smart object, go to its parent, save it and that’ll update main template. Then, you can just use Ctrl+Shift+C to quickly copy it to the main atlas.

## Other notes:

- You can edit any script while AC is running. With built-in Lua Debug app (at the bottom of apps list), you can see any errors which might occur, with full stack trace.
- Use `ac.debug("label", value)` to see the value in Lua Debug app.
- Notice how that app also shows time your script takes each frame. Keep it might there is only 16 ms available to get to 60 FPS, and, of course, most of that is already taken by the rest of rendering code. You don’t really need to update everything each frame though.
- If you would have any questions about any functions, please let me know.