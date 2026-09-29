/// Pure game constants ported from index.html.
library;

const double dotSpacing = 25; // m between sampled dots along a road
const double fieldRadius = 200; // m, clip radius around origin
const double eatRadius = 12; // m
const double catchRadius = 10; // m

const double ghostSpeed = 0.9; // m/s
const int powerMs = 30000; // power pellet duration

// Old speed-only flight rule (fallback when pedometer unavailable).
const double flightKmhFallback = 15;
const double resumeKmhFallback = 13;

// New pedometer-aware flight rule.
const double flightEnterSpeedKmh = 3;
const double flightForceEnterSpeedKmh = 25;
const double flightResumeOnFootSpeedKmh = 22;
const double flightResumeSlowSpeedKmh = 2;

const int speedWindowMs = 10000; // GPS speed averaging window
const int onFootWindowMs = 10000; // step/status freshness window

const int graphMergeDivisor = 1; // unused placeholder (kept for parity)

// Road snapping (matches SNAP_MAX / SWITCH_ROAD_PENALTY in index.html).
const double snapMax = 25; // m: farther than this from any road = off road
const double switchRoadPenalty = 5; // m: penalty for leaving the current road

// Marker glide: markers animate to their new position over this long.
const int glideDurationMs = 1000;

// Graph link thresholds (matches DOT_SPACING * 0.7 / * 1.05 in index.html).
const double roadLinkProximity = dotSpacing * 0.7; // 17.5 m
const double gridLinkProximity = dotSpacing * 1.05; // 26.25 m
const double nodeMergeDistance = dotSpacing * 0.6; // 15 m

const List<int> ghostColors = [0xffff0000, 0xffffbbbb, 0xff00ffff, 0xffffaa00];

const int scoreDot = 10;
const int scorePower = 50;
const int scoreGhost = 200;

const int startLives = 3;

const double simStepMeters = 5;
