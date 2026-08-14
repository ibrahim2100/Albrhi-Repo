//
//  SCIPanelDomain.h
//  Albrhi Panel
//
//  The preference domain every page in this bundle writes to, named once. Two spellings
//  of this string across SCIPanelRoot.m and a per-tweak settings page is exactly the
//  "switch that appears to work and changes nothing" mistake shared/src/SCIPanelGate.h
//  already warns about, for the reading side of the same domain.
//
#define kSCIPanelPreferenceDomain @"com.albrhi.panel"
