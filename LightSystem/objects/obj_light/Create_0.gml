// Customizable per light instance
//my_color   = c_orange;    // e.g., c_red, make_color_rgb(255, 165, 0)
//radius     = 350;         // Spread amount (pixels from center)
//intensity  = 1.0;         // 0.5 = dimmer, 2.0 = brighter

// Light type (instance setting)
//light_type    = "point";  // "point" = 360-degree radial, "spot" = directional cone
//light_direction = 0;      // Spotlight direction in degrees (0=right, 90=up in GM coords)
//cone_angle    = 45;       // Spotlight half-angle in degrees (total arc = cone_angle * 2)
//cone_softness = 0.2;      // Soft edge: 0 = hard cut, 1 = fully gradual falloff
//
//
////Overrides
//light_type = "spot";

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