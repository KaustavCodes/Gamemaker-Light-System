// Customizable per light instance
//my_color   = c_orange;    // e.g., c_red, make_color_rgb(255, 165, 0)
//radius     = 350;         // Spread amount (pixels from center)
//intensity  = 1.0;         // 0.5 = dimmer, 2.0 = brighter

// Spotlight settings — all per-instance, safe defaults let point lights work without changes.
// Override any of these on a specific instance to turn it into a spotlight.
//light_type       = "point";  // "point" = 360° radial  |  "spot" = directional cone
//light_direction  = 0;        // Spotlight aim in degrees (0 = right, 90 = down in GM coords)
//cone_angle       = 45;       // Spotlight outer half-angle in degrees (total arc = cone_angle*2)
//cone_inner_angle = 0;        // Explicit beam width override (degrees). 0 = use cone_softness.
                              //   e.g. 35 → full brightness inside 35°, falloff 35°→cone_angle
//cone_softness    = 0.7;      // Beam fill fraction (0-1+). 0 = pointy gradient, 0.7 = 70% flat
                              //   beam, 1.0 = entire cone flat (hard cut). Values >1 treated as 1.

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