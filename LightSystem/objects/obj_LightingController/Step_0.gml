// Skip rebuild when the world is static and the buffer is already frozen.
// Wrapped in a block so future Step logic added below is unaffected.
if (!static_world || rebuild_vb) {

    var _vb = vb;
    var vx = camera_get_view_x(view_camera[0]);
    var vy = camera_get_view_y(view_camera[0]);
    var vw = camera_get_view_width(view_camera[0]);
    var vh = camera_get_view_height(view_camera[0]);

    // --- P2: Dirty-flag check ------------------------------------------------
    // Only rebuild the vertex buffer when at least one blocker's transform has
    // changed since the last frame (or when an external rebuild_vb flag is set).
    var _any_dirty = rebuild_vb;  // honour manual rebuild requests
    with (obj_light_block) {
        if (x != _prev_x || y != _prev_y
            || image_angle  != _prev_angle
            || image_xscale != _prev_xscale
            || image_yscale != _prev_yscale
            || width  != _prev_width
            || height != _prev_height
            || radius != _prev_radius
            || cast_shadow != _prev_cast_shadow) {
            _dirty = true;
        }
        if (_dirty) { _any_dirty = true; }
    }

    if (!_any_dirty) exit;  // nothing changed — skip the entire rebuild
    // -------------------------------------------------------------------------

    // If the buffer was frozen (static_world was true) but we now need to rebuild,
    // delete and recreate it so vertex_begin() can write to it again.
    if (vb_frozen) {
        vertex_delete_buffer(_vb);
        vb    = vertex_create_buffer();
        _vb   = vb;
        vb_frozen = false;
    }

    vertex_begin(_vb, vf);

    with (obj_light_block) {
        // Per-instance toggle — skip this blocker entirely if cast_shadow is false.
        if (!cast_shadow) continue;

        // Frustum culling: compute a conservative bounding radius and skip if off-screen.
        var _bx = width  * abs(image_xscale);
        var _by = height * abs(image_yscale);
        var _bc = radius * max(abs(image_xscale), abs(image_yscale));
        var _br = max(_bx, _by, _bc) + 64;
        if (x + _br < vx || x - _br > vx + vw || y + _br < vy || y - _br > vy + vh) continue;

        var px, py, num_points;

        switch (shape) {
            case "rect":
                // Oriented Bounding Box: rotate and scale corners from the object's origin.
                var hw  = width  * abs(image_xscale) * 0.5;
                var hh  = height * abs(image_yscale) * 0.5;
                var ang = image_angle;
                var lx4 = [-hw,  hw, hw, -hw];
                var ly4 = [-hh, -hh, hh,  hh];
                px = array_create(4);
                py = array_create(4);
                for (var i = 0; i < 4; i++) {
                    px[i] = x + lx4[i] * dcos(ang) + ly4[i] * dsin(ang);
                    py[i] = y - lx4[i] * dsin(ang) + ly4[i] * dcos(ang);
                }
                num_points = 4;
                break;

            case "circle":
                // Dynamic Ellipse: independent x/y radii via image_xscale / image_yscale.
                var sides    = circle_sides;
                var ang_step = 360 / sides;
                var rx = radius * abs(image_xscale);
                var ry = radius * abs(image_yscale);
                px = array_create(sides);
                py = array_create(sides);
                for (var i = 0; i < sides; i++) {
                    var a = i * ang_step;
                    px[i] = x + rx * dcos(a);
                    py[i] = y - ry * dsin(a);  // GM y+ down
                }
                num_points = sides;
                break;

            case "polygon":
                // P7: points is now a native array instead of ds_list.
                if (points == -1 || array_length(points) < 3) continue;
                num_points = array_length(points);
                px = array_create(num_points);
                py = array_create(num_points);
                var ang = image_angle;
                for (var i = 0; i < num_points; i++) {
                    var pt = points[i];
                    var lx = pt[0];
                    var ly = pt[1];
                    px[i] = x + lx * dcos(ang) + ly * dsin(ang);
                    py[i] = y - lx * dsin(ang) + ly * dcos(ang);
                }
                break;

            default: continue;
        }

        // Optional front cap (self-shadow on the blocker surface)
        if (other.use_front_caps) {
            for (var i = 1; i < num_points - 1; i++) {
                vertex_position_3d(_vb, px[0],     py[0],     0);
                vertex_position_3d(_vb, px[i],     py[i],     0);
                vertex_position_3d(_vb, px[i + 1], py[i + 1], 0);
            }
        }

        // Edge extrusions
        for (var i = 0; i < num_points; i++) {
            var j = (i + 1) mod num_points;
            Quad(_vb, px[i], py[i], px[j], py[j]);
        }

        // Reset dirty state and cache current transform for next frame.
        _dirty = false;
        _prev_x  = x;
        _prev_y  = y;
        _prev_angle  = image_angle;
        _prev_xscale = image_xscale;
        _prev_yscale = image_yscale;
        _prev_width  = width;
        _prev_height = height;
        _prev_radius = radius;
        _prev_cast_shadow = cast_shadow;
    }

    vertex_end(_vb);

    // Freeze the buffer when static_world is enabled (zero CPU cost after first build).
    if (static_world) {
        vertex_freeze(_vb);
        vb_frozen = true;
    }
    rebuild_vb = false;

} // end rebuild block