shape = "rect";    // "rect", "circle", or "polygon" (instance setting)
cast_shadow = true; // Toggle shadow casting on/off for this blocker (instance setting)

// Rect-specific (auto-set from sprite; override manually if needed)
// Rotation and scale are read from the built-in image_angle, image_xscale, image_yscale vars.
width  = sprite_width;
height = sprite_height;

// Circle-specific
// Ellipse scaling is driven by image_xscale / image_yscale (stretch to oval automatically).
radius       = sprite_width / 2;
circle_sides = 16;  // Tessellation quality: 8=blocky, 16=default, 32=smooth (instance setting)

// Polygon-specific: ds_list of [lx, ly] local-coordinate arrays, relative to origin (0,0).
// The engine rotates and translates them using image_angle and x/y each frame.
// Example:
//   points = ds_list_create();
//   ds_list_add(points, [-16, -16], [16, -16], [16, 16], [-16, 16]);
points = -1;

image_alpha = 0;