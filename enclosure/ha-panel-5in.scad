// Echo Show–style desk enclosure for the Elecrow DIS05490T 5" touchscreen
// with a Raspberry Pi 3 mounted on its back.
//
// Three printed parts + 4 small clamps:
//   bezel       front frame. The display + Pi screw onto it. Print face-down.
//   body        the wedge-shaped shell. Print with its open front on the bed.
//   back_plate  vented back panel with the cable notch. Print outside-face down.
//   clamp       holds a corner of the display PCB (print 4).
//   preview     everything assembled, with a ghost display + Pi for checking.
//
// The bezel holds to the body with 4 pairs of 8x2 mm magnets (no visible
// screws). The back plate uses 4 countersunk M3x8 screws; the display clamps
// 4 more M3x8. All screw holes are sized for self-tapping into plastic.

/* [Part] */
part = "preview"; // [preview, bezel, body, back_plate, clamp]

/* [Display — CHECK WITH CALIPERS BEFORE PRINTING] */
// Display PCB outline (width, looking at the screen)
board_w = 137;
// Display PCB outline (height)
board_h = 80;
// Visible (active) screen area
active_w = 108;
active_h = 64.8;
// Active-area centre relative to PCB centre. + = right, looking at the screen
active_off_x = -2;
// Active-area centre relative to PCB centre. + = up
active_off_y = 3;
// Front of the glass to the back surface of the display PCB (at the corners)
pcb_back_depth = 7.5;

/* [Case shape] */
width = 178;
// Height of the front face, measured along the tilt
face_height = 132;
// Screen tilt back from vertical (degrees)
tilt = 18;
// Depth across the top of the case
top_depth = 34;
// Depth across the bottom (sets how deep the wedge is)
base_depth = 88;
wall = 2.4;
bezel_thickness = 4;
front_radius = 2.5;
back_radius = 16;
base_back_radius = 12;
// Space between the bottom of the display PCB and the bottom of the face (room for the Pi's plugs)
board_bottom = 30;
// Extra window size around the active area, per side
window_margin = 1;

/* [Fit] */
// Clearance around the display PCB
board_clear = 0.4;
// Clearance between back plate and its opening, per side
plate_clear = 0.25;
// Clearance between the bezel's locating lip and the body
lip_clear = 0.3;
// Pilot hole for M3 self-tapping screws
pilot_d = 2.6;
magnet_d = 8;
magnet_h = 2;
// Extra room in the magnet pockets (diameter)
magnet_clear = 0.3;

/* [Hidden] */
$fn = 40;
eps = 0.01;
bt = bezel_thickness;
lip_t = 1.6;
lip_h = 3;

// ---------------------------------------------------------------------------
// Side profile (Y = depth, Z = height). Corners: 0 front-bottom, 1 front-top,
// 2 back-top, 3 back-bottom.
sA = sin(tilt);
cA = cos(tilt);
P = [
  [0, 0],
  [face_height * sA, face_height * cA],
  [face_height * sA + top_depth, face_height * cA],
  [base_depth, 0],
];
R = [front_radius, front_radius, back_radius, base_back_radius];

function unit(v) = v / norm(v);
// Centre of a circle of radius d tucked into profile corner i.
function corner_center(i, d) =
  let (p = P[i], a = unit(P[(i + 3) % 4] - p), b = unit(P[(i + 1) % 4] - p),
       half = acos(a * b) / 2)
  p + unit(a + b) * d / sin(half);

// The top-back rounding must not reach the front face.
function dist_to_front(c) = abs(c[0] * cA - c[1] * sA);
assert(dist_to_front(corner_center(2, R[2])) > R[2] + wall,
       "back_radius is too big for this top_depth — increase top_depth or reduce back_radius");

// Face frame: u = across, v = up the tilted face, w = out of the face
// (w < 0 is inside the case). Origin at the front-bottom edge.
M_face = [[1, 0, 0, 0], [0, sA, -cA, 0], [0, cA, sA, 0], [0, 0, 0, 1]];
M_face_inv = [[1, 0, 0, 0], [0, sA, cA, 0], [0, -cA, sA, 0], [0, 0, 0, 1]];
function to_face(p) = [p[0], sA * p[1] + cA * p[2], -cA * p[1] + sA * p[2]];

// Back frame: u = across, v = up the back face, w = into the case.
B = unit(P[2] - P[3]);
M_back = [[1, 0, 0, 0], [0, B[0], -B[1], P[3][0]], [0, B[1], B[0], P[3][1]], [0, 0, 0, 1]];
function back_to_stand(p) =
  [p[0], P[3][0] + B[0] * p[1] - B[1] * p[2], P[3][1] + B[1] * p[1] + B[0] * p[2]];

// Display placement, with the screen centred left-right on the face.
win_cu = width / 2;
win_cv = board_bottom + board_h / 2 + active_off_y;
win_w = active_w + 2 * window_margin;
win_h = active_h + 2 * window_margin;
win_flare = bt - 1.2;  // 45° bevel around the window, leaving a 1.2 mm straight edge
board_u0 = win_cu - active_off_x - board_w / 2;
board_v0 = board_bottom;

// Back opening: the flat part of the back face, less a margin.
back_side_r = max(R[2], R[3]);
open_u0 = back_side_r + 3;
open_u1 = width - back_side_r - 3;
open_v0 = (corner_center(3, R[3]) - P[3]) * B + 3;
open_v1 = (corner_center(2, R[2]) - P[3]) * B - 3;
open_r = 5;
boss_r = 5;
boss_h = 8;
boss_pts = [for (u = [open_u0 + 7, open_u1 - 7], v = [open_v0 + 7, open_v1 - 7]) [u, v]];

// Clamp posts sit just above/below the PCB, 7 mm in from its side edges.
post_d = 8;
post_pts = [
  for (side = [0, 1], end = [0, 1])
    [side == 0 ? board_u0 + 7 : board_u0 + board_w - 7,
     end == 0 ? board_v0 - board_clear - post_d / 2
              : board_v0 + board_h + board_clear + post_d / 2]
];

// Magnet blocks in the body's front corners, where the inside of the front
// opening meets the floor/top wall.
seam_w = -bt;
v_floor = (wall - sA * seam_w) / cA;                   // inner floor at the seam
v_roof = (P[1][1] - wall - sA * seam_w) / cA;          // inner top wall at the seam
mag_block = 13;
mag_pts = [
  for (u = [wall + mag_block / 2 - 0.5, width - wall - mag_block / 2 + 0.5],
       v = [v_floor + mag_block / 2 - 0.5, v_roof - mag_block / 2 + 0.5]) [u, v]
];

echo(str("Outside size: ", width, " W x ", round(P[1][1]), " H x ", base_depth, " D mm"));
echo(str("Bezels: sides ", (width - win_w) / 2, " mm, top ", face_height - (win_cv + win_h / 2),
         " mm, chin ", win_cv - win_h / 2, " mm"));

// ---------------------------------------------------------------------------
// Helpers

module profile_body(offset_in = 0) {
  hull() for (i = [0 : 3]) {
    r = offset_in == 0 ? R[i] : max(R[i] - offset_in, 0.8);
    c = corner_center(i, offset_in + r);
    for (x = [offset_in + r, width - offset_in - r])
      translate([x, c[0], c[1]]) sphere(r = r, $fn = r > 5 ? 72 : 24);
  }
}

module in_face() { multmatrix(M_face) children(); }
module in_back() { multmatrix(M_back) children(); }

// Everything in front of / behind the bezel seam.
module front_of_seam() { in_face() translate([-10, -50, seam_w]) cube([width + 20, face_height + 100, 20]); }
// (a hair short of the seam so CGAL never cuts exactly through a sphere vertex)
module behind_seam() { in_face() translate([-10, -50, -200]) cube([width + 20, face_height + 100, 200 + seam_w - 0.003]); }

module rounded_rect(u0, v0, u1, v1, r) {
  translate([u0 + r, v0 + r]) offset(r = r) square([u1 - u0 - 2 * r, v1 - v0 - 2 * r]);
}

// ---------------------------------------------------------------------------
// Bezel

module window_cut() {
  in_face() hull() {
    translate([win_cu - win_w / 2, win_cv - win_h / 2, seam_w - 1]) cube([win_w, win_h, 1 + 1.2]);
    translate([win_cu - win_w / 2 - win_flare - 1, win_cv - win_h / 2 - win_flare - 1, 1])
      cube([win_w + 2 * win_flare + 2, win_h + 2 * win_flare + 2, eps]);
  }
}

module display_mounts() {
  in_face() {
    // Clamp posts
    for (p = post_pts)
      translate([p[0], p[1], seam_w - pcb_back_depth]) cylinder(d = post_d, h = pcb_back_depth + eps);
    // L-shaped corner guides that locate the PCB
    gh = pcb_back_depth - 1;
    for (cu = [0, 1], cv = [0, 1]) {
      x = cu == 0 ? board_u0 - board_clear : board_u0 + board_w + board_clear;
      y = cv == 0 ? board_v0 - board_clear : board_v0 + board_h + board_clear;
      translate([x, y, seam_w - gh]) linear_extrude(gh + eps)
        scale([cu == 0 ? -1 : 1, cv == 0 ? -1 : 1])
          difference() {
            translate([-6, -6]) square([7.6, 7.6]);
            translate([-6.1, -6.1]) square([6.1, 6.1]);
          }
    }
  }
}

// Thin wall on the back of the bezel that slips inside the body and keeps it aligned.
module locating_lip() {
  difference() {
    intersection() {
      profile_body(wall + lip_clear);
      in_face() translate([-10, -50, seam_w - lip_h]) cube([width + 20, face_height + 100, lip_h + eps]);
    }
    profile_body(wall + lip_clear + lip_t);
    for (p = mag_pts)
      in_face() translate([p[0] - mag_block / 2 - 1, p[1] - mag_block / 2 - 1, seam_w - lip_h - 1])
        cube([mag_block + 2, mag_block + 2, lip_h + 2]);
  }
}

module bezel() {
  difference() {
    union() {
      intersection() { profile_body(); front_of_seam(); }
      locating_lip();
      display_mounts();
    }
    window_cut();
    for (p = post_pts)
      in_face() translate([p[0], p[1], seam_w - pcb_back_depth - 1]) cylinder(d = pilot_d, h = pcb_back_depth);
    for (p = mag_pts)
      in_face() translate([p[0], p[1], seam_w - eps])
        cylinder(d = magnet_d + magnet_clear, h = magnet_h + 0.1);
  }
}

// ---------------------------------------------------------------------------
// Body

// Screw bosses for the back plate, each braced by a gusset that keeps every
// overhang at or under 45° when the body prints front-down.
module plate_bosses() {
  roof_z = P[1][1] - wall;
  for (p = boss_pts) {
    s1 = back_to_stand([p[0], p[1] - boss_r, wall]);
    s2 = back_to_stand([p[0], p[1] + boss_r, wall + boss_h]);
    hull() {
      in_back() translate([p[0], p[1], wall]) cylinder(r = boss_r, h = boss_h);
      if (p[1] > (open_v0 + open_v1) / 2) {
        // Upper bosses hang from the top wall.
        drop = roof_z - min(s1[2], s2[2]);
        y1 = min(s1[1], s2[1]) - 0.65 * drop;
        translate([p[0] - boss_r, y1, roof_z]) cube([2 * boss_r, max(s1[1], s2[1]) - y1, 1]);
      } else {
        // Lower bosses brace against the side wall.
        left = p[0] < width / 2;
        prot = (left ? p[0] - wall : width - wall - p[0]) + boss_r;
        f1 = to_face(s1);
        f2 = to_face(s2);
        in_face()
          translate([left ? wall - 1 : width - wall, min(f1[1], f2[1]), min(f1[2], f2[2]) - 1])
            cube([1, abs(f1[1] - f2[1]), abs(f1[2] - f2[2]) + prot + 1]);
      }
    }
  }
}

module magnet_blocks() {
  for (p = mag_pts)
    in_face() translate([p[0] - mag_block / 2, p[1] - mag_block / 2, seam_w - 5])
      cube([mag_block, mag_block, 5]);
}

module floor_vents() {
  // Front-to-back slots under the Pi (they print as short bridges).
  n = 9;
  for (i = [0 : n - 1])
    translate([win_cu - (n - 1) * 3.5 + i * 7 - 1.5, 30, -1]) cube([3, 26, wall + 2]);
}

module feet_recesses() {
  for (x = [20, width - 20], y = [16, base_depth - 22])
    translate([x, y, -eps]) cylinder(d = 12.5, h = 1);
}

module body() {
  difference() {
    intersection() {
      union() {
        difference() { profile_body(); profile_body(wall); }
        // Trimmed 1 mm into the wall so they fuse with the shell cleanly.
        intersection() {
          profile_body(wall - 1);
          union() { plate_bosses(); magnet_blocks(); }
        }
      }
      behind_seam();
    }
    // Back opening
    in_back() translate([0, 0, -1])
      linear_extrude(wall + 1 + eps) rounded_rect(open_u0, open_v0, open_u1, open_v1, open_r);
    for (p = boss_pts) in_back() translate([p[0], p[1], wall - 1]) cylinder(d = pilot_d, h = boss_h + 2);
    for (p = mag_pts)
      in_face() translate([p[0], p[1], seam_w - magnet_h - 0.1])
        cylinder(d = magnet_d + magnet_clear, h = magnet_h + 1);
    floor_vents();
    feet_recesses();
  }
}

// ---------------------------------------------------------------------------
// Back plate (built in the back frame: outside face at z = 0)

module back_plate() {
  c = plate_clear;
  mid_u = (open_u0 + open_u1) / 2;
  difference() {
    linear_extrude(wall)
      rounded_rect(open_u0 + c, open_v0 + c, open_u1 - c, open_v1 - c, open_r - c);
    // Countersunk M3 holes
    for (p = boss_pts) translate([p[0], p[1], 0]) {
      translate([0, 0, -1]) cylinder(d = 3.3, h = wall + 2);
      translate([0, 0, -eps]) cylinder(d1 = 6.4, d2 = 3.3, h = 1.55);
    }
    // Cable notch at the bottom edge
    translate([0, 0, -1]) linear_extrude(wall + 2)
      hull() {
        translate([mid_u - 12, open_v0 - 1]) square([24, 1]);
        for (s = [-1, 1]) translate([mid_u + s * 7, open_v0 + c + 9]) circle(r = 5);
      }
    // Speaker-style vent grille over the upper half (hot air from the Pi exits here)
    gv0 = (open_v0 + open_v1) / 2 - 6;
    gv1 = open_v1 - 9;
    pitch = 6;
    translate([0, 0, -1])
      for (row = [0 : floor((gv1 - gv0) / (pitch * 0.866))])
        for (col = [0 : floor((open_u1 - open_u0 - 34) / pitch)]) {
          u = open_u0 + 17 + col * pitch + (row % 2) * pitch / 2;
          v = gv0 + row * pitch * 0.866;
          if (u < open_u1 - 17) translate([u, v]) cylinder(d = 3.4, h = wall + 2, $fn = 16);
        }
  }
}

// ---------------------------------------------------------------------------
// Display clamp: screws onto a post and overlaps the PCB edge by 4 mm.

module clamp() {
  len = post_d / 2 + board_clear + 4;
  difference() {
    hull() {
      cylinder(d = post_d + 2, h = 3);
      translate([-(post_d + 2) / 2, 0, 0]) cube([post_d + 2, len, 3]);
    }
    translate([0, 0, -1]) cylinder(d = 3.3, h = 5);
  }
}

// ---------------------------------------------------------------------------
// Ghost display + Pi for the preview (approximate — for clearance checks only)

module ghost_hardware() {
  in_face() {
    // Glass
    color("black") translate([win_cu - 121 / 2, board_v0 + 4, seam_w - 5.9]) cube([121, 76, 5.9]);
    // Display PCB and back-side parts
    color("#2a3a2a") translate([board_u0, board_v0, seam_w - pcb_back_depth]) cube([board_w, board_h, 1.6]);
    color("#555") translate([board_u0 + 30, board_v0 + 10, seam_w - 14]) cube([board_w - 40, board_h - 20, 14 - pcb_back_depth]);
    // Pi 3 on standoffs, Ethernet/USB end on the left, HDMI + power along the bottom
    pi_u0 = board_u0 - 6;
    pi_d = pcb_back_depth + 8;
    color("green") translate([pi_u0, board_v0, seam_w - pi_d - 1.5]) cube([85, 56, 1.5]);
    color("silver") translate([pi_u0, board_v0 + 2, seam_w - pi_d - 1.5 - 16]) cube([21, 53, 16]);
    color("#444") translate([pi_u0 + 25, board_v0 + 6, seam_w - pi_d - 1.5 - 9]) cube([55, 46, 9]);
    // Right-angle plugs: Pi HDMI + power (down), display HDMI + USB-C (right)
    color("orange") {
      translate([pi_u0 + 85 - 32 - 8, board_v0 - 18, seam_w - pi_d - 8]) cube([16, 18, 8]);
      translate([pi_u0 + 85 - 10.6 - 4, board_v0 - 14, seam_w - pi_d - 6]) cube([8, 14, 5]);
      translate([board_u0 + board_w, board_v0 + 30, seam_w - 12]) cube([14, 16, 8]);
      translate([board_u0 + board_w, board_v0 + 55, seam_w - 11]) cube([12, 9, 6]);
    }
  }
}

// ---------------------------------------------------------------------------
// Print orientations (rotations only — never mirrored)

// Face frame -> bed, looking at the part from the back: (u, v, w) -> (u, -v, -w - z0)
module face_down(z0 = 0) {
  translate([0, 0, -z0]) rotate([180, 0, 0]) multmatrix(M_face_inv) children();
}

if (part == "bezel") face_down() bezel();
else if (part == "body") face_down(-seam_w + 0.003) body();
else if (part == "back_plate") back_plate();
else if (part == "clamp") clamp();
else {
  color("#3b3f46") body();
  color("#2c2f35") bezel();
  color("#3b3f46") in_back() back_plate();
  %ghost_hardware();
  for (p = post_pts)
    color("#2c2f35") in_face() translate([p[0], p[1], seam_w - pcb_back_depth - 3])
      rotate([0, 0, p[1] < board_v0 ? 0 : 180]) clamp();
}
