// --- P9: Per-blocker shadow vertex buffer rebuild ---
//
// Each obj_light_block owns its own shadow_vb (frozen vertex buffer).
// The controller rebuilds it only when the blocker's transform has changed (_dirty flag).
// In Draw_0 the shadow pass submits only the VBs for blockers within each light's radius,
// eliminating the cost of sending distant geometry to the GPU for every light.

// Handle rebuild_vb flag: force every blocker to regenerate its VB this frame
// (used when blockers are added/removed at runtime, e.g., obj_LightingController.rebuild_vb = true).
if (rebuild_vb) {
    with (obj_light_block) { _dirty = true; }
    rebuild_vb = false;
}

// Camera extents used for frustum culling — cached once here before the per-blocker loop.
var _vx = camera_get_view_x(view_camera[0]);
var _vy = camera_get_view_y(view_camera[0]);
var _vw = camera_get_view_width(view_camera[0]);
var _vh = camera_get_view_height(view_camera[0]);

// Per-blocker dirty detection + VB rebuild.
with (obj_light_block) {

    // --- P2: Auto-detect transform changes and mark dirty ---
    if (x != _prev_x || y != _prev_y
        || image_angle  != _prev_angle
        || image_xscale != _prev_xscale
        || image_yscale != _prev_yscale
        || width  != _prev_width
        || height != _prev_height
        || radius != _prev_radius
        || cast_shadow != _prev_cast_shadow
        || block_opacity != _prev_block_opacity) {
        _dirty = true;
    }

    // Skip this blocker if nothing has changed and a valid VB is already built.
    if (!_dirty && shadow_vb != -1) continue;

    // In static_world mode, skip rebuilds once the initial VB has been built.
    if (other.static_world && shadow_vb != -1) continue;

    // --- Cache current transform (clears dirty for next frame) ---
    _prev_x           = x;
    _prev_y           = y;
    _prev_angle       = image_angle;
    _prev_xscale      = image_xscale;
    _prev_yscale      = image_yscale;
    _prev_width       = width;
    _prev_height      = height;
    _prev_radius        = radius;
    _prev_cast_shadow   = cast_shadow;
    _prev_block_opacity = block_opacity;
    _dirty              = false;

    // Tear down the existing VB before rebuilding.
    if (shadow_vb != -1) {
        vertex_delete_buffer(shadow_vb);
        shadow_vb = -1;
    }
    if (fill_vb != -1) {
        vertex_delete_buffer(fill_vb);
        fill_vb = -1;
    }

    // Non-shadow-casters keep shadow_vb = -1 (skipped in the Draw pass).
    if (!cast_shadow) continue;

    // --- Frustum cull: don't build a VB for fully off-screen blockers ---
    // (shadow_vb stays -1; it is built automatically when the blocker becomes visible.)
    var _bx = width  * abs(image_xscale);
    var _by = height * abs(image_yscale);
    var _bc = radius * max(abs(image_xscale), abs(image_yscale));
    var _br = max(_bx, _by, _bc) + 64;
    if (x + _br < _vx || x - _br > _vx + _vw
        || y + _br < _vy || y - _br > _vy + _vh) continue;

    // --- Compute polygon vertices for this blocker's shape ---
    var px = [];
    var py = [];
    var num_points = 0;
    var _valid = true;

    switch (shape) {
        case "rect":
            // Use the sprite's origin offset so the shadow polygon matches the room-editor
            // placement exactly (WYSIWYG).  sprite_get_xoffset/yoffset returns the pixel
            // position of the origin within the sprite; corners are expressed relative to
            // that pivot before rotation and scale are applied.
            var _xoff = sprite_get_xoffset(sprite_index);
            var _yoff = sprite_get_yoffset(sprite_index);
            var _sx   = abs(image_xscale);
            var _sy   = abs(image_yscale);
            var ang   = image_angle;
            var lx4   = [-_xoff * _sx,         (width - _xoff) * _sx, (width - _xoff) * _sx, -_xoff * _sx];
            var ly4   = [-_yoff * _sy,         -_yoff * _sy,           (height - _yoff) * _sy, (height - _yoff) * _sy];
            px = array_create(4);
            py = array_create(4);
            for (var i = 0; i < 4; i++) {
                px[i] = x + lx4[i] * dcos(ang) + ly4[i] * dsin(ang);
                py[i] = y - lx4[i] * dsin(ang) + ly4[i] * dcos(ang);
            }
            num_points = 4;
            break;

        case "circle":
            // Offset the circle centre to the visual centre of the sprite so that the
            // shadow matches the room-editor placement regardless of sprite origin.
            var _xoff    = sprite_get_xoffset(sprite_index);
            var _yoff    = sprite_get_yoffset(sprite_index);
            var ang      = image_angle;
            var sides    = circle_sides;
            var ang_step = 360 / sides;
            var rx = radius * abs(image_xscale);
            var ry = radius * abs(image_yscale);
            // Local-space offset from pivot to sprite visual centre (before rotation).
            var _lcx = (width  * 0.5 - _xoff) * abs(image_xscale);
            var _lcy = (height * 0.5 - _yoff) * abs(image_yscale);
            // Rotate centre offset around the pivot and translate to world space.
            var _wcx = x + _lcx * dcos(ang) + _lcy * dsin(ang);
            var _wcy = y - _lcx * dsin(ang) + _lcy * dcos(ang);
            px = array_create(sides);
            py = array_create(sides);
            for (var i = 0; i < sides; i++) {
                var a = i * ang_step;
                px[i] = _wcx + rx * dcos(a);
                py[i] = _wcy - ry * dsin(a);  // GM y+ down
            }
            num_points = sides;
            break;

        case "polygon":
            // points is a native GML array of [lx, ly] pairs (migrated from ds_list in P7).
            if (points == -1 || array_length(points) < 3) { _valid = false; break; }
            num_points = array_length(points);
            px = array_create(num_points);
            py = array_create(num_points);
            var ang = image_angle;
            var _sx = abs(image_xscale);
            var _sy = abs(image_yscale);
            for (var i = 0; i < num_points; i++) {
                var pt = points[i];
                var lx = pt[0] * _sx;  // apply scale before rotation
                var ly = pt[1] * _sy;
                px[i] = x + lx * dcos(ang) + ly * dsin(ang);
                py[i] = y - lx * dsin(ang) + ly * dcos(ang);
            }
            break;

        default: _valid = false; break;
    }

    if (!_valid) continue;

    // --- Build this blocker's shadow vertex buffer ---
    var _new_vb = vertex_create_buffer();
    vertex_begin(_new_vb, other.vf);

    // Optional front cap (self-shadow on the blocker surface).
    if (other.use_front_caps) {
        for (var i = 1; i < num_points - 1; i++) {
            vertex_position_3d(_new_vb, px[0],     py[0],     0);
            vertex_position_3d(_new_vb, px[i],     py[i],     0);
            vertex_position_3d(_new_vb, px[i + 1], py[i + 1], 0);
        }
    }

    // Edge extrusions.
    for (var i = 0; i < num_points; i++) {
        var j = (i + 1) mod num_points;
        Quad(_new_vb, px[i], py[i], px[j], py[j]);
    }

    vertex_end(_new_vb);
    // Always freeze: per-blocker VBs are small and rebuilt on-demand when dirty.
    vertex_freeze(_new_vb);
    shadow_vb = _new_vb;

    // --- Build flat fill polygon VB for partial-opacity blocker pass ---
    // When block_opacity < 1.0 the Draw pass injects (1-opacity) of each light back
    // into the blocked footprint via an additional shd_light call.  The fill VB is a
    // simple fan triangulation of the same polygon (z = 0, no extrusion needed).
    if (block_opacity < 1.0) {
        var _fvb = vertex_create_buffer();
        vertex_begin(_fvb, other.vf);
        for (var i = 1; i < num_points - 1; i++) {
            vertex_position_3d(_fvb, px[0],     py[0],     0);
            vertex_position_3d(_fvb, px[i],     py[i],     0);
            vertex_position_3d(_fvb, px[i + 1], py[i + 1], 0);
        }
        vertex_end(_fvb);
        vertex_freeze(_fvb);
        fill_vb = _fvb;
    }

} // end per-blocker rebuild loop