if (!flicker_enabled) exit;

// Intensity flicker
flicker_timer += delta_time / 1000000;
if (flicker_timer > random_range(0.05, 0.2)) {
    flicker_target = base_intensity + random_range(flicker_min, flicker_max);
    // Sync wobble change with flicker for natural feel
    wobble_target_x = random_range(-wobble_amp, wobble_amp);
    wobble_target_y = random_range(-wobble_amp, wobble_amp);
    flicker_timer = 0;
}

// Smooth lerp intensity
var lerp_speed = 8;
intensity = lerp(intensity, flicker_target, lerp_speed * (delta_time / 1000000));

// Smooth wobble position (apply offset)
x = lerp(x, base_x + wobble_target_x, lerp_speed * (delta_time / 1000000));
y = lerp(y, base_y + wobble_target_y, lerp_speed * (delta_time / 1000000));