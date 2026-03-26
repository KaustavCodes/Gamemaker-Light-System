if (surface_exists(light_surface)) {
    surface_free(light_surface);
}
if (vertex_format_exists(vf)) {
    vertex_format_delete(vf);
}
if (vb != -1) {
    vertex_delete_buffer(vb);
}