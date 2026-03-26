/// @function scr_path_to_polygon(path_name)
/// @desc    Converts a GameMaker Path asset into a ds_list of [lx, ly] local-coordinate
///          arrays ready for use as obj_light_block polygon points.
///
///          Path points should be authored relative to (0, 0) in the Path editor so that
///          they act as local offsets from the blocker's origin.  The engine will then
///          rotate and translate them each frame using image_angle and x/y.
///
/// @param   {Asset.GMPath} path_name  The path asset to convert.
/// @returns {DS.DSList}  A ds_list of [lx, ly] arrays.
///          The caller is responsible for destroying the list when done (ds_list_destroy).
function scr_path_to_polygon(path_name) {
    var _n   = path_get_number(path_name);
    var _pts = ds_list_create();
    for (var _i = 0; _i < _n; _i++) {
        ds_list_add(_pts, [path_get_point_x(path_name, _i),
                           path_get_point_y(path_name, _i)]);
    }
    return _pts;
}
