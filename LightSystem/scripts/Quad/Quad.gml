/// @function Quad(_vb, _x1, _y1, _x2, _y2)
/// @desc Adds shadow-casting quad (two triangles) to vertex buffer
function Quad(_vb, _x1, _y1, _x2, _y2) {
    // Triangle 1: Negative diagonal
    vertex_position_3d(_vb, _x1, _y1, 0);     // Static
    vertex_position_3d(_vb, _x1, _y1, 1);     // Extrude target
    vertex_position_3d(_vb, _x2, _y2, 0);     // Static
    
    // Triangle 2: Positive diagonal
    vertex_position_3d(_vb, _x1, _y1, 1);     // Extrude target
    vertex_position_3d(_vb, _x2, _y2, 0);     // Static
    vertex_position_3d(_vb, _x2, _y2, 1);     // Extrude target
}