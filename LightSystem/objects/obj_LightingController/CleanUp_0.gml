if (surface_exists(light_surface))  surface_free(light_surface);
if (surface_exists(blur_surface_h)) surface_free(blur_surface_h);
if (surface_exists(blur_surface_v)) surface_free(blur_surface_v);
if (vertex_format_exists(vf)) {
    vertex_format_delete(vf);
}
// depth_clear_vb is always created in Create_0 and never set to -1 during normal operation.
// The guard below is a defensive safety check in case the Create event was interrupted.
if (depth_clear_vb != -1) {
    vertex_delete_buffer(depth_clear_vb);
}
// Per-blocker shadow VBs are owned by obj_light_block instances and freed in their Destroy events.