# odin-webgl-experiments

Demo projects using [Odin]("https://odin-lang.org/") compiled to WebAssembly and rendered using WebGL

[jlafayette.github.io/odin-webgl-experiments](https://jlafayette.github.io/odin-webgl-experiments/)

## Useful Resources

### Resizing and Zooming

[webglfundamentals webgl-resizing-the-canvas](https://webglfundamentals.org/webgl/lessons/webgl-resizing-the-canvas.html)

### Phone Compatibility

Had a problem when the phone is vertical, the window size wasn't being set right and the
aspect ratio was off and top of content cut off.  Took a while to find the answer:

[stackoverflow question](https://stackoverflow.com/questions/26799330/why-does-window-innerheight-return-180-when-in-horizontal-orientation)

[Viewport meta tag](https://developer.mozilla.org/en-US/docs/Web/HTML/Viewport_meta_tag)
