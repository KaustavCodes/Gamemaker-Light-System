if (surface_exists(light_surface))  surface_free(light_surface);
if (surface_exists(blur_surface_h)) surface_free(blur_surface_h);
if (surface_exists(blur_surface_v)) surface_free(blur_surface_v);
if (vertex_format_exists(vf)) {
    vertex_format_delete(vf);
}
if (vb != -1) {
    vertex_delete_buffer(vb);
}