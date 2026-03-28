Dynamic 2D Lighting System for GameMaker Studio 2
=================================================

This project implements a performant GPU-based 2D dynamic lighting system for GameMaker Studio 2 (GMS2). It allows for real-time rendering of multiple customizable lights (with color, radius, and intensity) and hard shadows cast from basic obstacle shapes. The system uses shaders and vertex buffers to handle lighting efficiently, making it suitable for games requiring atmospheric effects like shadows in top-down views.

About the Project
-----------------

*   **Purpose**: To provide an easy-to-integrate lighting solution that enhances 2D game visuals without heavy performance costs.
    
*   **Key Components**: A controller object manages rendering; light objects emit illumination; blocker objects cast shadows.
    
*   **Inspired By**: Optimized techniques like the "Ultra-Fast 2D Dynamic Lighting" method.
    
*   **Limitations**: Best for axis-aligned or simple convex shapes; no built-in support for rotations or concave blockers.
    

Features
--------

*   Multiple lights with per-instance customization.
    
*   Shadows from rectangles, circles, or polygons.
    
*   Global ambient darkness control.
    
*   Light culling for optimization.
    
*   Extensible for effects like flickering.

*   Per-light adjustable attenuation curve (linear, quadratic, cubic, or custom exponent).

*   Soft shadow blur with precomputed Gaussian kernel (no GPU-side `exp()` overhead).

*   Automatic surface resize handling (window resize, fullscreen toggle).

*   Dirty-flag vertex buffer rebuild — only recomputes shadow geometry when blockers actually move.
    

Prerequisites
-------------

*   GameMaker Studio 2 (v2.3+).
    
*   Basic GML knowledge.
    
*   Target: Desktop/mobile (Z-buffer required; HTML5 limited).
    

Installation
------------

1.  Download the repository and extract the files.
    
2.  Import into GMS2: Open the project file or drag assets (objects, shaders, scripts) into your IDE.
    
3.  Ensure shaders (shd\_light, shd\_shadow) and script (Quad) are included—see the shaders/ and scripts/ folders for details.
    

How to Use
----------

Follow these steps to add lighting to your room:

### 1\. Add the Main Controller

*   Place one instance of obj\_LightingController in your room (on a background layer).
    
*   This object initializes the system, builds the shadow geometry, and renders lights/shadows in its Draw event.
    
*   Customize in its Create event (e.g., ambient\_alpha = 0.5; for darker scenes).
    

### 2\. Add Obstacles (Shadow Blockers)

*   Place instances of obj\_light\_block where you want shadows (e.g., walls or objects).
    
*   Assign a sprite for visuals if desired (the system uses shape data for shadows).
    
*   Set shape via room editor variables or Creation Code:gmlshape = "rect"; // Default: rectangle// Or "circle" or "polygon"
    
*   For size: Set width, height, or radius (0 = auto-detect from sprite).
    
*   Example for a circle:gmlshape = "circle";radius = 32; // Or 0 for sprite-based
    

### 3\. Add Lights

*   Place instances of obj\_light where you want light sources.
    
*   Customize via variables:gmlmy\_color = c\_white; // e.g., c\_redradius = 256; // Spread distanceintensity = 1.0; // Brightness
    
*   No sprite needed—the light is rendered via shader.
    

### 4\. Run the Room

*   Lights will illuminate the scene with gradients, blending where they overlap.
    
*   Shadows cast dynamically from blockers.
    
*   If blockers change (move/add/remove), set obj\_LightingController.rebuild\_vb = true; to update shadows.
    

Example
-------

*   Create a room with obj\_light\_block instances as walls (rect shapes).
    
*   Add an obj\_light near the player with yellow color and medium radius.
    
*   Result: Areas light up, with shadows behind walls.
    

Customization Tips
------------------

*   **Darker Blockers**: Set use\_front\_caps = true; in controller for self-shadows.
    
*   **Flickering Light**: In obj\_light Step: intensity = 1.0 + 0.2 \* sin(current\_time \* 0.01);.
    
*   **Performance**: For static scenes, set static\_world = true; in the controller to freeze shadow geometry (zero CPU cost).

*   **Attenuation Curve**: Set attenuation\_exponent on an obj\_light instance. 1.0 = linear (gentle), 2.0 = quadratic (default), 3.0 = cubic (concentrated). Any positive value works.

*   **Polygon Blockers**: Use scr\_path\_to\_polygon() to convert a Path asset into a native array of points, then assign to obj\_light\_block.points.
    

Troubleshooting
---------------

*   No lights/shadows? Check controller placement and room layers.
    
*   Artifacts? Ensure shapes are convex; test with fewer sides for circles.
    
*   Lag? Reduce light count or cull more aggressively.
    

For full code details, check the source files. Contributions welcome—fork and PR!