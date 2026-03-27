/// @function scr_path_to_polygon(path_name)
/// @desc    Converts a GameMaker Path asset into a native array of [lx, ly]
///          local-coordinate arrays ready for use as obj_light_block polygon points.
///
///          Path points should be authored relative to (0, 0) in the Path editor so that
///          they act as local offsets from the blocker's origin.  The engine will then
///          rotate and translate them each frame using image_angle and x/y.
///
/// @param   {Asset.GMPath} path_name  The path asset to convert.
/// @returns {Array}  A native array of [lx, ly] arrays.
function scr_path_to_polygon(path_name) {
    var _n   = path_get_number(path_name);
    var _pts = array_create(_n);
    for (var _i = 0; _i < _n; _i++) {
        _pts[_i] = [path_get_point_x(path_name, _i),
                     path_get_point_y(path_name, _i)];
    }
    return _pts;
}
