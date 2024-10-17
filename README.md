# odin-webgl-experiments

Demo projects using [Odin]("https://odin-lang.org/") compiled to WebAssembly and rendered using WebGL

[jlafayette.github.io/odin-webgl-experiments](https://jlafayette.github.io/odin-webgl-experiments/)

## Prerequisites

Odin (uses fork at [jlafayette/Odin](https://github.com/jlafayette/Odin))
Go (for dev server)
Python (for build/publish scripts)

To build an example with the dev server:

```shell
python build.py <example-name>
```

## Useful Resources

### Resizing and Zooming

[webglfundamentals webgl-resizing-the-canvas](https://webglfundamentals.org/webgl/lessons/webgl-resizing-the-canvas.html)

### Phone Compatibility

Had a problem when the phone is vertical, the window size wasn't being set right and the
aspect ratio was off and top of content cut off.  Took a while to find the answer:

[stackoverflow question](https://stackoverflow.com/questions/26799330/why-does-window-innerheight-return-180-when-in-horizontal-orientation)

[Viewport meta tag](https://developer.mozilla.org/en-US/docs/Web/HTML/Viewport_meta_tag)

## TODO

[ ] multi: Have js send if running on mobile
[ ] multi: Buttons for mobile inputs to cycle things
[ ] camera: Smooth acceleration (mostly for keyboard to feel nice)
[ ] camera: Switch to spaceship controls (continue moving with maybe a small amount of friction)
[ ] camera: support mobile controls
[ ] new: Buttons (do main menu example)
[ ] new: Sound queues and pools (can have buttons)
[ ] sounds: Add volume slider
[ ] synth_keyboard: Use [DynamicsCompressorNode](https://developer.mozilla.org/en-US/docs/Web/API/DynamicsCompressorNode)
[ ] camera: determine N_CUBES from query parameters if provided
[ ] camera: set fog distance and color with uniforms
