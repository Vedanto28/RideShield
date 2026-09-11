// ============================================================
// RideShield — Rider Map Component (Hybrid SVG + Leaflet WebView)
// ============================================================

import React, { useRef, useEffect } from 'react';
import { View, StyleSheet, Platform } from 'react-native';
import { WebView } from 'react-native-webview';

interface RiderMapProps {
  location: { latitude: number; longitude: number } | null;
  routeCoords: { latitude: number; longitude: number }[];
  style?: any;
}

export function RiderMap({ location, routeCoords, style }: RiderMapProps) {
  const webViewRef = useRef<WebView>(null);

  const lat = location?.latitude ?? 28.6139;
  const lng = location?.longitude ?? 77.209;

  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { width: 100%; height: 100%; background: #0f172a; overflow: hidden; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        #wrapper { width: 100%; height: 100%; position: relative; }
        #svg-layer { width: 100%; height: 100%; position: absolute; top: 0; left: 0; z-index: 1; background: #0f172a; }
        #map { width: 100%; height: 100%; position: absolute; top: 0; left: 0; z-index: 2; background: transparent; }
        
        .pulse {
          animation: radar 2s infinite ease-out;
          transform-origin: center;
        }
        @keyframes radar {
          0% { r: 8px; opacity: 0.9; stroke-width: 2px; }
          100% { r: 36px; opacity: 0; stroke-width: 0.5px; }
        }

        .leaflet-div-pin {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          background: rgba(13, 148, 136, 0.25);
          border: 2px solid #0d9488;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 0 16px rgba(13, 148, 136, 0.6);
        }
        .leaflet-div-core {
          width: 12px;
          height: 12px;
          border-radius: 50%;
          background: #0d9488;
          box-shadow: 0 0 8px #0d9488;
        }
      </style>
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    </head>
    <body>
      <div id="wrapper">
        <!-- SVG Vector Map Fallback (0ms Offline Render) -->
        <svg id="svg-layer" viewBox="0 0 400 400" preserveAspectRatio="xMidYMid slice">
          <defs>
            <pattern id="grid" width="30" height="30" patternUnits="userSpaceOnUse">
              <path d="M 30 0 L 0 0 0 30" fill="none" stroke="#1e293b" stroke-width="1"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="#0f172a"/>
          <rect width="100%" height="100%" fill="url(#grid)"/>
          
          <!-- Road Grid Visuals -->
          <path d="M -20 180 C 120 140, 220 260, 420 200" fill="none" stroke="#334155" stroke-width="14" stroke-linecap="round"/>
          <path d="M -20 180 C 120 140, 220 260, 420 200" fill="none" stroke="#475569" stroke-width="10" stroke-linecap="round"/>
          
          <path d="M 180 -20 L 220 420" fill="none" stroke="#334155" stroke-width="12"/>
          <path d="M 180 -20 L 220 420" fill="none" stroke="#475569" stroke-width="8"/>
          
          <!-- Dynamic Polyline Trail -->
          <path id="svg-trail" d="" fill="none" stroke="#0d9488" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>

          <!-- Dynamic Radar Pulse Marker -->
          <g id="svg-marker" transform="translate(200, 200)">
            <circle class="pulse" cx="0" cy="0" r="12" fill="none" stroke="#0d9488"/>
            <circle cx="0" cy="0" r="14" fill="rgba(13, 148, 136, 0.2)" stroke="#0d9488" stroke-width="2"/>
            <circle cx="0" cy="0" r="6" fill="#0d9488"/>
          </g>
        </svg>

        <!-- Leaflet Map Container -->
        <div id="map"></div>
      </div>

      <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <script>
        var initialLat = ${lat};
        var initialLng = ${lng};
        var mapInstance = null;
        var markerInstance = null;
        var polylineInstance = null;

        function initLeaflet() {
          try {
            if (typeof L !== 'undefined' && L.map) {
              mapInstance = L.map('map', {
                zoomControl: false,
                attributionControl: false
              }).setView([initialLat, initialLng], 16);

              L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
                maxZoom: 19,
                subdomains: 'abcd'
              }).addTo(mapInstance);

              var icon = L.divIcon({
                html: '<div class="leaflet-div-pin"><div class="leaflet-div-core"></div></div>',
                className: '',
                iconSize: [32, 32],
                iconAnchor: [16, 16]
              });

              markerInstance = L.marker([initialLat, initialLng], { icon: icon }).addTo(mapInstance);
              var initialCoords = ${JSON.stringify(routeCoords.map(c => [c.latitude, c.longitude]))};
              polylineInstance = L.polyline(initialCoords, {
                color: '#0d9488',
                weight: 5,
                opacity: 0.85
              }).addTo(mapInstance);

              document.getElementById('svg-layer').style.display = 'none';
            }
          } catch (err) {
            console.log('Leaflet load deferred, using SVG vector map:', err);
          }
        }

        setTimeout(initLeaflet, 200);

        function updatePosition(newLat, newLng, coordsArray) {
          if (mapInstance && markerInstance) {
            var pos = [newLat, newLng];
            markerInstance.setLatLng(pos);
            mapInstance.panTo(pos, { animate: true, duration: 0.5 });
            if (polylineInstance && coordsArray && coordsArray.length > 0) {
              polylineInstance.setLatLngs(coordsArray);
            }
          }
        }
      </script>
    </body>
    </html>
  `;

  useEffect(() => {
    if (location && webViewRef.current) {
      const coordsArray = routeCoords.map(c => [c.latitude, c.longitude]);
      const js = `updatePosition(${location.latitude}, ${location.longitude}, ${JSON.stringify(coordsArray)}); true;`;
      webViewRef.current.injectJavaScript(js);
    }
  }, [location, routeCoords]);

  if (Platform.OS === 'web') {
    const offset = 0.005;
    const bbox = `${lng - offset}%2C${lat - offset}%2C${lng + offset}%2C${lat + offset}`;
    const embedUrl = `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&layer=mapnik&marker=${lat}%2C${lng}`;

    return (
      <View style={[{ backgroundColor: '#0f172a', overflow: 'hidden' }, style]}>
        <iframe
          src={embedUrl}
          width="100%"
          height="100%"
          style={{ border: 0 }}
          title="OpenStreetMap"
        />
      </View>
    );
  }

  return (
    <View style={[StyleSheet.absoluteFill, { backgroundColor: '#0f172a' }, style]}>
      <WebView
        ref={webViewRef}
        originWhitelist={['*']}
        source={{ html: htmlContent, baseUrl: 'https://localhost' }}
        style={{ flex: 1, backgroundColor: 'transparent' }}
        scrollEnabled={false}
        bounces={false}
        showsHorizontalScrollIndicator={false}
        showsVerticalScrollIndicator={false}
        javaScriptEnabled={true}
        domStorageEnabled={true}
        androidLayerType="software"
        mixedContentMode="always"
      />
    </View>
  );
}
