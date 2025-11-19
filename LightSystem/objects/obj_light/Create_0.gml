// Customizable per light
//my_color   = c_orange;    // e.g., c_red, make_color_rgb(255, 165, 0)
//radius     = 350;        // Spread amount (pixels from center)
//intensity  = 1.0;        // 0.5 = dimmer, 2.0 = brighter


// Flicker setup (randomized per light)
// Flicker & Wobble setup (randomized per light)
//flicker_enabled = true;  // Toggle to enable/disable
base_intensity = 0.9;
flicker_min = -0.3;
flicker_max = 0.1;
intensity = base_intensity;
flicker_target = base_intensity;
flicker_timer = 0;

// Wobble vars (small shifts like candle)
base_x = x;
base_y = y;
wobble_target_x = 0;
wobble_target_y = 0;
wobble_amp = 5;  // Max pixels shift (tune 1-4 for subtle)