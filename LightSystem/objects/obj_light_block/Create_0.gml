shape = "rect";    // "rect", "circle", or "polygon" (instance setting)
cast_shadow = true; // Toggle shadow casting on/off for this blocker (instance setting)

// Rect-specific (auto-set from sprite; override manually if needed)
// Rotation and scale are read from the built-in image_angle, image_xscale, image_yscale vars.
// Use sprite_get_width/height (unscaled) so that the Step VB builder can apply
// image_xscale / image_yscale itself without double-counting.
width  = sprite_get_width(sprite_index);
height = sprite_get_height(sprite_index);

// Circle-specific
// Ellipse scaling is driven by image_xscale / image_yscale (stretch to oval automatically).
radius       = sprite_get_width(sprite_index) / 2;
circle_sides = 16;  // Tessellation quality: 8=blocky, 16=default, 32=smooth (instance setting)

// Polygon-specific: array of [lx, ly] local-coordinate arrays, relative to origin (0,0).
// The engine rotates and translates them using image_angle and x/y each frame.
// Example:
//   points = [[-16, -16], [16, -16], [16, 16], [-16, 16]];
points = -1;

image_alpha = 0;

// Opacity: 0.0 = light passes through completely, 1.0 = fully blocks light (default).
// Values in between let a proportional fraction of each light through the blocker's footprint.
block_opacity = 1.0;

// P9: Per-blocker shadow vertex buffer.
// The controller builds and freezes this VB the first time the blocker is processed and
// rebuilds it whenever the blocker's transform changes (dirty-flagged).  The shadow pass
// in Draw_0.gml submits only the VBs for blockers within each light's radius, eliminating
// the cost of submitting distant blockers for every light.
shadow_vb = -1;  // vertex_buffer_id; -1 = not yet built
fill_vb   = -1;  // flat polygon VB used for partial-opacity light pass; -1 = not built

// Dirty tracking: the controller rebuilds this blocker's shadow_vb when the flag is set.
// Previous-frame values are stored here for automatic change detection.
_dirty   = true;   // start dirty so initial build always runs
_prev_x  = x;
_prev_y  = y;
_prev_angle  = image_angle;
_prev_xscale = image_xscale;
_prev_yscale = image_yscale;
_prev_width  = width;
_prev_height = height;
_prev_radius = radius;
_prev_cast_shadow = cast_shadow;
_prev_block_opacity = block_opacity;