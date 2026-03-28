// points is a native array — no manual cleanup needed (GC handles it).
// P9: Free this blocker's per-blocker shadow vertex buffer.
if (shadow_vb != -1) {
    vertex_delete_buffer(shadow_vb);
    shadow_vb = -1;
}