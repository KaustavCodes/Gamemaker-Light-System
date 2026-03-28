// Customizable per light instance
//my_color   = c_orange;    // e.g., c_red, make_color_rgb(255, 165, 0)
//radius     = 350;         // Spread amount (pixels from center)
//intensity  = 1.0;         // 0.5 = dimmer, 2.0 = brighter

// Per-instance on/off switch.
// Set active = false to disable a light completely (no shadow pass, no light draw).
// This is cheaper than destroying and recreating the instance and preserves all
// light state (color, flicker timer, easing targets) while the light is off.
active = true;

// Attenuation curve — controls how light intensity falls off with distance.
// 1.0 = linear (gentle, wide spread), 2.0 = quadratic (default, natural),
// 3.0 = cubic (sharp, concentrated).  Any positive value is valid.
attenuation_exponent = 2.0;

// Spotlight settings — all per-instance, safe defaults let point lights work without changes.
// Override any of these on a specific instance to turn it into a spotlight.
//light_type       = "point";  // "point" = 360° radial  |  "spot" = directional cone
//light_direction  = 0;        // Spotlight aim in degrees (0 = right, 90 = down in GM coords)
//cone_angle       = 45;       // Spotlight outer half-angle in degrees (total arc = cone_angle*2)
//cone_inner_angle = 0;        // Flat-top beam-origin width in PIXELS. 0 = pointy single-point tip.
                              //   e.g. 200 = 200 px wide flat origin (trapezoidal beam shape).
//cone_softness    = 0.7;      // Edge softness 0..1. 0 = full angular gradient from centre.
                              //   0.7 = 70% of cone is uniformly bright; 1.0 = hard cut at edge.

// Flicker & Wobble setup (randomized per light)
//flicker_enabled = true;  // Toggle to enable/disable
base_intensity = 0.9;
flicker_min = -0.3;
flicker_max = 0.1;
intensity = base_intensity;
flicker_target = base_intensity;
flicker_timer = 0;

// Intensity & Radius easing (instance setting — smooth turn on/off or expand/contract)
target_intensity     = base_intensity;  // Ease intensity toward this value each step
intensity_ease_speed = 0;               // 0 = instant snap; >0 = lerp speed (e.g., 5.0)
target_radius        = -1;              // -1 = use radius directly; >=0 = ease toward this
radius_ease_speed    = 0;               // 0 = instant; >0 = lerp speed (e.g., 3.0)

// Wobble vars (small shifts like candle)
base_x = x;
base_y = y;
wobble_target_x = 0;
wobble_target_y = 0;
wobble_amp = 5;  // Max pixels shift (tune 1-4 for subtle)

// P8: Normal-map lighting — height of this light above the 2-D XY plane (world units).
// Larger values produce shallower angles and gentler normal-based shading on flat surfaces.
// Only used when obj_LightingController.normal_map_surface is set to a valid surface.
light_z = 200.0;