//shape = "rect";  // "rect" (default), "circle", or "polygon"

// Rect-specific
width = sprite_width;   // Auto if sprite; or set manually
height = sprite_height;

// Circle-specific
radius = sprite_width / 2;            // Adjust for size

// Polygon-specific: ds_list of [x,y] arrays (convex, ordered)
points = -1;            // e.g., ds_list_create(); ds_list_add(points, [x-16,y-16], [x+16,y-16], [x+16,y+16], [x-16,y+16]);


image_alpha = 0;

// In Create: mask_index = sprite_index;  // Use sprite's mask