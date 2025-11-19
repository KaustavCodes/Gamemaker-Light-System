if (rebuild_vb) {
    vertex_begin(vb, vf);
    var _vb = vb;
    
    with (obj_light_block) {
        var px, py, num_points;
        
        switch (shape) {
            case "rect":
                var w = width, h = height;
                px = [x, x + w, x + w, x];
                py = [y, y, y + h, y + h];
                num_points = 4;
                break;
                
            case "circle":
                var sides = 16;  // Tune: 8=blocky, 32=smoother
                var ang_step = 360 / sides;
                px = array_create(sides);
                py = array_create(sides);
                for (var i = 0; i < sides; i++) {
                    var ang = i * ang_step;
                    px[i] = x + radius * dcos(ang);
                    py[i] = y - radius * dsin(ang);  // GM y+ down
                }
                num_points = sides;
                break;
                
            case "polygon":
                if (points == -1 || ds_list_size(points) < 3) continue;
                num_points = ds_list_size(points);
                px = array_create(num_points);
                py = array_create(num_points);
                for (var i = 0; i < num_points; i++) {
                    var pt = points[| i];
                    px[i] = pt[0];
                    py[i] = pt[1];
                }
                break;
                
            default: continue;
        }
        
        // Optional front cap (self-shadow)
        if (other.use_front_caps) {
            for (var i = 1; i < num_points - 1; i++) {
                vertex_position_3d(_vb, px[0], py[0], 0);
                vertex_position_3d(_vb, px[i], py[i], 0);
                vertex_position_3d(_vb, px[i + 1], py[i + 1], 0);
            }
        }
        
        // Edge extrusions
        for (var i = 0; i < num_points; i++) {
            var j = (i + 1) mod num_points;
            Quad(_vb, px[i], py[i], px[j], py[j]);
        }
    }
    
    vertex_end(vb);
    // vertex_freeze(vb);  // Uncomment if blocks are static
    rebuild_vb = false;
}